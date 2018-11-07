# AUTOR: Andrés Gavín Murillo y Borja Aguado
# NIAs: 716358 y 741440
# FICHERO: chat.exs
# FECHA: noviembre de 2018
# TIEMPO: 10 horas
# DESCRIPCIÓN: Chat completamente distribuido

defmodule Chat do
  # shared_vars (mutex) pertenece [0,1]
  # pendiente = lista de pids que quieren el mutex
  def binary_semaphore(shared_vars, pendiente) do
    receive do
      {pid, :wait} ->
        if shared_vars == 1 do
          send(pid, {:ok})
          binary_semaphore(0, [])
        else
          binary_semaphore(shared_vars, [pid])
        end

      {pid, :signal} ->
        if length(pendiente) == 0 do
          binary_semaphore(1, pendiente)
        else
          send(hd(pendiente), {:ok})
          binary_semaphore(0, [])
        end
    end
  end


    # osn = our_sequence_number
    # hsn = highest_sequence_number
    # orc = outstanding_reply_count
    # rcs = requesting_critical_section
    # rd = reply_deferred
  def database(osn, hsn, orc, rcs, rd) do
    receive do
      {:write, :osn, valor} ->
        database(valor, hsn, orc, rcs, rd)

      {:write, :hsn, valor} ->
        database(osn, valor, orc, rcs, rd)

      {:write, :orc, valor} ->
        database(osn, hsn, valor, rcs, rd)

      {:write, :rcs, valor} ->
        database(osn, hsn, orc, valor, rd)

      {:write, :rd, valor} ->
        database(osn, hsn, orc, rcs, valor)

      {:read, :osn, pid} ->
        send(pid, {:osn, osn})
        database(osn, hsn, orc, rcs, rd)

      {:read, :hsn, pid} ->
        send(pid, {:hsn, hsn})
        database(osn, hsn, orc, rcs, rd)

      {:read, :orc, pid} ->
        send(pid, {:orc, orc})
        database(osn, hsn, orc, rcs, rd)

      {:read, :rcs, pid} ->
        send(pid, {:rcs, rcs})
        database(osn, hsn, orc, rcs, rd)

      {:read, :rd, pid} ->
        send(pid, {:rd, rd})
        database(osn, hsn, orc, rcs, rd)
    end
  end


  # [node | nodes] = Lista de direcciones de los nodos (ej: [:"nodo1@ip1", :"nodo2@ip2"])
  # msj_type = Nombre registrado (ej: :request_process)
  # msj = Mensaje a enviar
  # sendMe = booleano; Si es true, el mensaje se lo manda tambíen a si mismo, en otro caso no.
  defp all_nodes_sender([node | nodes], msj_type, msj, sendMe) do
    if sendMe or node != Node.self() do
      send({msj_type, node}, msj)
    end

    if length(nodes) != 0 do
      all_nodes_sender(nodes, msj_type, msj, sendMe)
    end
  end

  # [node | nodes] = Lista de direcciones de los nodos (ej: [:"nodo1@ip1", :"nodo2@ip2"])
  # [rd | rds] = Reply_Deferred
  # result = []
  defp post_protocol([node | nodes], [rd | rds], result, piddb) do
    if rd do
      send({:reply_process, node}, {:reply})
    end

    if length(nodes) != 0 do
      post_protocol(nodes, rds, result++[false], piddb)
    else
      send(piddb, {:write, :rd, result++[false]})
    end
  end

  # me = Número único
  # n = Número de nodos totales conectados
  # nodes = Lista de direcciones de los nodos (ej: [:"nodo1@ip1", :"nodo2@ip2"])
  def mutual_exclusion_invoker(pidmutex, piddb, me, n, nodes) do
    message = IO.gets "-> " # Waiting for sending a message

    # Pre-protocol: Request Entry  to our Critical Section
    send(pidmutex, {self(), :wait})
    receive do
      # Choose a sequence number
      {:ok} ->
        send(piddb, {:write, :rcs, true})
        send(piddb, {:read, :hsn, self()})
        receive do
          {:hsn, hsn} -> send(piddb, {:write, :osn, hsn + 1})
        end

        send(piddb, {:write, :orc, n - 1})
        send(piddb, {:read, :osn, self()})
        receive do
          {:osn, osn} ->
            all_nodes_sender(nodes, :request_process, {:request, osn, me, Node.self()}, false)
            # Sent a REQUEST message containing our sequence number and
            # our node number to all other nodes
        end
        send(pidmutex, {self(), :signal})
    end
    # Now wait for a REPLY from each of the other nodes
    receive do
      {:reply_end} ->
        # Critical Section Processing can be performed at this point
        all_nodes_sender(nodes, :chat_process, {:message, Node.self(), message}, true)
        # Release the Critical Section
    end

    # Post-protocol
    send(pidmutex, {self(), :wait})
    receive do
      {:ok} ->
        send(piddb, {:read, :rd, self()})
        receive do
          {:rd, rd} ->
            post_protocol(nodes, rd, [], piddb)
        end
        send(piddb, {:write, :rcs, false})
        send(pidmutex, {self(), :signal})
    end

    mutual_exclusion_invoker(pidmutex, piddb, me, n, nodes)
  end


  def reply_receiver_init(pidmutex, piddb, pidinvoker) do
    Process.register(self(), :reply_process)
    reply_receiver(pidmutex, piddb, pidinvoker)
  end

  defp reply_receiver(pidmutex, piddb, pidinvoker) do
    receive do # Waiting for a reply
      {:reply} ->
        spawn(fn ->
          send(pidmutex, {self(), :wait})
          receive do
            {:ok} ->
              send(piddb, {:read, :orc, self()})
              receive do
                {:orc, orc} ->
                  if orc == 1 do
                    send(pidinvoker, {:reply_end})
                  end
                  send(piddb, {:write, :orc, orc - 1})
              end

              send(pidmutex, {self(), :signal})
          end
        end)
    end

    reply_receiver(pidmutex, piddb, pidinvoker)
  end


  # me = Número único
  def request_receiver_init(pidmutex, piddb, me) do
    Process.register(self(), :request_process)
    request_receiver(pidmutex, piddb, me)
  end

  # me = Número único
  defp request_receiver(pidmutex, piddb, me) do
    receive do # Waiting for a request
      {:request, k, j, idnode} ->
        spawn(fn ->
          # k is the sequence number begin requested, j is the node number making the request
          defer_it = false
          send(pidmutex, {self(), :wait})
          receive do
            {:ok} ->
              send(piddb, {:read, :hsn, self()})
              receive do
                {:hsn, hsn} ->
                  if hsn < k do
                    send(piddb, {:write, :hsn, k})
                  end
              end
              #defer_it = ( RCS && k>OSN ) || (k=OSN && j>me)
              send(piddb, {:read, :rcs, self()})
              receive do
                {:rcs, rcs} ->
                  send(piddb, {:read, :osn, self()})
                  receive do
                    {:osn, osn} ->
                      defer_it = (rcs and k>osn) or (k==osn and j>me)
                  end
              end
              # Defer_it will be true if we have priority over node j's request
              #if defer_it then Reply_deferred[j] = true
              if defer_it do
                send(piddb, {:read, :rd, self()})
                receive do
                  {:rd, lista_rd} ->
                    # modificada[j] = true
                    modificada = List.replace_at(lista_rd, j-1, true)
                    send(piddb, {:write, :rd, modificada})
                end
              else
                send({:reply_process, idnode}, {:reply})
              end
              send(pidmutex, {self(), :signal})
          end
        end)
    end

    request_receiver(pidmutex, piddb, me)
  end


  def chat_receiver_init() do
    Process.register(self(), :chat_process)
    chat_receiver()
  end

  # Recibe mensajes de chat y los imprime por pantalla
  defp chat_receiver() do
    receive do
      {:message, idnodo, msj} ->
        IO.puts "#{idnodo}: #{msj}"
        chat_receiver()
    end
  end


  # Función principal del módulo Chat
  # Para ejecutar esta función, todos los nodos deben de estar previamente conectados
  #   me = Número único de este nodo [1..n]
  #   nodes = Lista de direcciones de todos los nodos de la red ordenados por su número único de
  #           menor a mayor. Ej: [:"nodo1@ip1", :"nodo2@ip2"], siendo nodo1 el nodo con número 1, y
  #           nodo2 el nodo con número 2.
  def main(me, nodes) do
    n = length(nodes) # Número de nodos en la red
    reply_deferred = for n <- 1..n, do: false # Ordenados igual que nodes
    piddb = spawn(Chat, :database, [0, 0, 0, false, reply_deferred])
    pidmutex = spawn(Chat, :binary_semaphore, [1, []])
    pidrequest = spawn(Chat, :request_receiver_init, [pidmutex, piddb, me])
    pidinvoker = self()
    pidreply = spawn(Chat, :reply_receiver_init, [pidmutex, piddb, pidinvoker])
    pidchat = spawn(Chat, :chat_receiver_init, [])
    mutual_exclusion_invoker(pidmutex, piddb, me, n, nodes)
  end
end

#Chat.main(1, [Node.self()])
