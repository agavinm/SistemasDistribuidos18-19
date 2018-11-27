# AUTOR: Andrés Gavín Murillo y Borja Aguado
# NIAs: 716358 y 741440
# FICHERO: master.exs
# FECHA: noviembre de 2018
# TIEMPO: 25 horas
# DESCRIPCIÓN: Master

defmodule Master do
  # Función principal del módulo Master
  # Para ejecutar esta función, todos los workers deben de estar previamente conectados
  # workers_t1 = Lista de direcciones de todos los workers de tipo :divisores
  # workers_t2 = Lista de direcciones de todos los workers de tipo :suma_divisores
  # workers_t3 = Lista de direcciones de todos los workers de tipo :suma_lista
  #   Ej lista: [:"worker1@ip1", :"worker2@ip2"]
  def main(workers_t1, workers_t2, workers_t3) do
    timeout = 100000
    retries = 10
    min = 1
    max = 10000

    spawn(Master, :master_t2, [self(), min, max, retries, timeout, workers_t2])
    spawn(Master, :master_t13, [self(), min, max, retries, timeout, workers_t1, workers_t3])
    receive do
      {:result, suma} ->
        calcular_amigos(suma, min)
    end

    IO.inspect("Ok")
  end

  def master_t2(pid, min, max, retries, timeout, workers_t2) do
    suma = for i <- min..max, do: calcular(i, 1, retries, timeout, workers_t2)
    send(pid, {:result, suma})
  end

  def master_t13(pid, min, max, retries, timeout, workers_t1, workers_t3) do
    lista_div_propios = for i <- min..max, do:
      List.delete(calcular(i, 1, retries, timeout, workers_t1), i)
    suma = for i <- lista_div_propios, do: calcular(i, 1, retries, timeout, workers_t3)
    send(pid, {:result, suma})
  end

  defp calcular(i, k, retries, timeout, [worker | workers]) do
    if k <= retries do
      send(worker, {:req, {self(), i}})
      #IO.inspect(i, label: "Send")
      receive do
        {:result, i, r} ->
          #IO.inspect({i,r}, label: "Receive")
          r
      after
        timeout ->
          if length(workers) > 0 do
            calcular(i, k+1, retries, timeout, workers)
          else
            IO.inspect(self(), label: "Error: Workers agotados")
          end
      end
    else
      IO.inspect(self(), label: "Error: Retries agotados")
    end
  end

  # Calcula los números amigos de la lista
  defp calcular_amigos([si | suma], i) do
    if length(suma) > 0 do
      calcular_amigos_i([si | suma], i, i, si)
      calcular_amigos(suma, i+1)
    end
  end

  # Calcula los números amigos de i de la lista
  defp calcular_amigos_i([sj | suma], j, i, si) do
    if sj == i && si == j do
      IO.inspect([i,j])
    else
      if length(suma) > 0 do
        calcular_amigos_i(suma, j+1, i, si)
      end
    end
  end
end

Node.connect(:"worker1a@127.0.0.1")
#Node.connect(:"worker1b@127.0.0.1")
Node.connect(:"worker2a@127.0.0.1")
#Node.connect(:"worker2b@127.0.0.1")
Node.connect(:"worker3a@127.0.0.1")
#Node.connect(:"worker3b@127.0.0.1")

worker_t1 = [{:worker1a, :"worker1a@127.0.0.1"}]
worker_t2 = [{:worker2a, :"worker2a@127.0.0.1"}]
worker_t3 = [{:worker3a, :"worker3a@127.0.0.1"}]

workers_t1 = [{:worker1a, :"worker1a@127.0.0.1"}, {:worker1b, :"worker1b@127.0.0.1"}]
workers_t2 = [{:worker2a, :"worker2a@127.0.0.1"}, {:worker2b, :"worker2b@127.0.0.1"}]
workers_t3 = [{:worker3a, :"worker3a@127.0.0.1"}, {:worker3b, :"worker3b@127.0.0.1"}]

Master.main(worker_t1, worker_t2, worker_t3)

#Master.main(workers_t1, workers_t2, workers_t3)
