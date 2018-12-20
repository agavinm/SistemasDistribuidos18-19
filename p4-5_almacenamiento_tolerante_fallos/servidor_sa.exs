# AUTOR: Andrés Gavín Murillo y Borja Aguado
# NIAs: 716358 y 741440
# FICHERO: servidor_sa.exs
# FECHA: diciembre de 2018
# TIEMPO: 15 h
# DESCRIPCIÓN: Servidor Servicio de Almacenamiento

Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do

    # estado del servidor
    defstruct num_vista: 0, primario: :undefined, copia: :undefined,
                valida: false, datos: %{}


    @intervalo_latido 50


    @doc """
        Obtener el hash de un string Elixir
            - Necesario pasar, previamente,  a formato string Erlang
         - Devuelve entero
    """
    def hash(string_concatenado) do
        String.to_charlist(string_concatenado) |> :erlang.phash2
    end

    @doc """
        Poner en marcha el servidor para gestión de vistas
        Devolver atomo que referencia al nuevo nodo Elixir
    """
    @spec startNodo(String.t, String.t) :: node
    def startNodo(nombre, maquina) do
                                         # fichero en curso
        NodoRemoto.start(nombre, maquina, __ENV__.file)
    end

    @doc """
        Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
    """
    @spec startService(node, node) :: pid
    def startService(nodoSA, nodo_servidor_gv) do
        NodoRemoto.esperaNodoOperativo(nodoSA, __MODULE__)

        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoSA, __MODULE__, :init_sa, [nodo_servidor_gv])
   end

    #------------------- Funciones privadas -----------------------------

    def init_sa(nodo_servidor_gv) do
        Process.register(self(), :servidor_sa)
        # Process.register(self(), :cliente_gv)


    #------------- VUESTRO CODIGO DE INICIALIZACION AQUI..........


        spawn(__MODULE__, :procesar_latido, [self()])
        # Poner estado inicial
        estado = %{num_vista: 0, primario: :undefined, copia: :undefined,
                    valida: false, datos: %{}}
        bucle_recepcion_principal(estado, nodo_servidor_gv)
    end

    def procesar_latido(pid) do
        send(pid, {:enviar_latido})
        Process.sleep(@intervalo_latido)
        procesar_latido(pid)
    end


    defp bucle_recepcion_principal(estado, nodo_servidor_gv) do
        {estado, nodo_servidor_gv} = receive do
            # Solicitudes de lectura y escritura
            # de clientes del servicio alm.
            {:lee, clave, pid} ->
                if (estado.valida == true && estado.primario == Node.self()) do
                    # Soy primario y la vista es válida
                    valor = Map.get(estado.datos, String.to_atom(clave))
                    valor =
                        if (valor == nil) do
                            ""
                        else
                            valor
                        end
                    send({:cliente_sa, pid}, {:resultado, valor})
                else # No soy primario o la vista no es válida
                    send({:cliente_sa, pid}, :error)
                end
                # Return estado
                {estado, nodo_servidor_gv}

            {:escribe_generico, {clave, valor, hash}, pid} ->
                {valor, estado} =
                    if (estado.valida == true && estado.primario ==
                            Node.self()) do
                        # Soy primario y la vista es válida
                        {valor, estado} = escribir(estado, clave, valor, hash)
                        # Enviar a copia
                        send({:servidor_sa, estado.copia}, {:escribe_generico,
                                {clave, valor, hash}, Node.self()})
                        # Enviar confirmación
                        send({:cliente_sa, pid}, {:resultado, valor})
                        {valor, estado}
                    else
                        if (estado.valida == true && estado.copia == Node.self()
                            && estado.primario == pid) do
                            # Soy copia y la vista es válida
                            escribir(estado, clave, valor, hash)
                        else # No soy primario ni copia o la vista no es válida
                            send({:cliente_sa, pid}, :error)
                            {valor, estado}
                        end
                    end
                # Return estado
                {estado, nodo_servidor_gv}

            {:copia_todo, datos} ->
                estado =
                    if (estado.copia == Node.self()) do
                        %{estado | datos: datos}
                    else
                        estado
                    end
                # Return estado
                {estado, nodo_servidor_gv}

            {:enviar_latido} ->
                {:vista_tentativa, vista, valida} =
                    ClienteGV.latido(nodo_servidor_gv, estado.num_vista)
                estadoAntes = estado
                estado = %{estado | num_vista: vista.num_vista, primario:
                            vista.primario, copia: vista.copia, valida: valida}
                if (estado.primario == Node.self() &&
                        estado.num_vista == 1) do
                    # Primer primario
                    ClienteGV.latido(nodo_servidor_gv, -1)
                else
                    if (estado.primario == Node.self() &&
                        estado.copia != estadoAntes.copia) do
                        # Soy primario y acaba de cambiar la copia
                        send({:servidor_sa, estado.copia}, {:copia_todo,
                                estado.datos})
                    end
                    ClienteGV.latido(nodo_servidor_gv, estado.num_vista)
                end
                # Return estado
                {estado, nodo_servidor_gv}
            end

        bucle_recepcion_principal(estado, nodo_servidor_gv)
    end

    #--------- Otras funciones privadas que necesiteis .......
    defp escribir(estado, clave, valor, hash) do
        valor =
            if (hash == true) do
                vAntes = Map.get(estado.datos, String.to_atom(clave))
                hash(vAntes <> valor)
            else
                valor
            end
        valor =
            if (valor == nil) do
                ""
            else
                valor
            end
        estado = %{estado | datos: Map.put(estado.datos,
                    String.to_atom(clave), valor)}
        {valor, estado} # Return
    end
end
