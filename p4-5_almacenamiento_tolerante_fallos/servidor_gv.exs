# AUTOR: Andrés Gavín Murillo y Borja Aguado
# NIAs: 716358 y 741440
# FICHERO: servidor_gv.exs
# FECHA: diciembre de 2018
# TIEMPO: 15 h
# DESCRIPCIÓN: Servidor Gestor de Vistas

require IEx # Para utilizar IEx.pry

defmodule ServidorGV do
    @moduledoc """
        modulo del servicio de vistas
    """

    # Tipo estructura de datos que guarda el estado del servidor de vistas
    # COMPLETAR  con lo campos necesarios para gestionar
    # el estado del gestor de vistas
    defstruct num_vista: 0, primario: :undefined, copia: :undefined

    # Constantes
    @latidos_fallidos 4

    @intervalo_latidos 50


    @doc """
        Acceso externo para constante de latidos fallios
    """
    def latidos_fallidos() do
        @latidos_fallidos
    end

    @doc """
        acceso externo para constante intervalo latido
    """
   def intervalo_latidos() do
       @intervalo_latidos
   end

   @doc """
        Generar un estructura de datos vista inicial
    """
    def vista_inicial() do
        %{num_vista: 0, primario: :undefined, copia: :undefined}
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
    @spec startService(node) :: boolean
    def startService(nodoElixir) do
        NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)

        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
   end

    #------------------- FUNCIONES PRIVADAS ----------------------------------

    # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
    def init_sv() do
        Process.register(self(), :servidor_gv)

        spawn(__MODULE__, :init_monitor, [self()]) # otro proceso concurrente

        #### VUESTRO CODIGO DE INICIALIZACION

        bucle_recepcion(vista_inicial(), vista_inicial(), [], true)
    end

    def init_monitor(pid_principal) do
        send(pid_principal, :procesa_situacion_servidores)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
    end

    # Se trabaja con vista tentativa, que será válida si es igual a vista válida
    # latidos = [{nodoPrimario, fallosPrimario}, {nodoCopia, fallosCopia},
    #            {nodoEspera1, fallosEspera1}, {nodoEspera2, fallosEspera2}, ..]
    defp bucle_recepcion(vista_valida, vista_tentativa, latidos, consistente) do
        {vista_valida, vista_tentativa, latidos, consistente} = receive do

            {:latido, n_vista_latido, nodo_emisor} ->
                if (consistente == true) do
                    if (n_vista_latido == 0) do # Recaída
                        # Se une un nodo con el latido reinicado (0 fallos)
                        latidos = latidos ++ [{nodo_emisor, 0}]

                        # Se comprueba si se añade a vista tentativa como
                        # primario, copia, o ninguno
                        if (length(latidos) == 1) do
                            # Nueva vista
                            vista_tentativa = %{vista_tentativa | num_vista:
                                                vista_tentativa.num_vista + 1}
                            vista_tentativa = %{vista_tentativa |
                                                primario: nodo_emisor}
                        end
                        if (length(latidos) == 2) do
                            # Nueva vista
                            vista_tentativa = %{vista_tentativa | num_vista:
                                                vista_tentativa.num_vista + 1}
                            vista_tentativa = %{vista_tentativa |
                                                copia: nodo_emisor}
                        end

                    else # Vista que tiene el nodo emisor
                        # Se le reinicia el latido (0 fallos)
                        latidos = for i <- latidos do
                            if (elem(i, 0) == nodo_emisor) do
                                {elem(i, 0), 0}
                            else
                                i
                            end
                        end

                        # Situación normal (sólo si n_vista_latido es num_vista
                        # de la tentativa).
                        # Si el nodo es el primario, se valida la tentativa
                        if (n_vista_latido == vista_tentativa.num_vista) do
                            if (nodo_emisor == vista_tentativa.primario) do
                                vista_valida = vista_tentativa
                            end
                        end
                    end
                end

                # Se envía la tentativa
                send({:servidor_sa, nodo_emisor}, {:vista_tentativa,
                        vista_tentativa, vista_tentativa == vista_valida})

                # Return estado
                {vista_valida, vista_tentativa, latidos, consistente}

            {:obten_vista, pid} ->
                # Se envía la valida
                send(pid, {:vista_valida, vista_valida,
                           vista_tentativa == vista_valida})

               # Return estado
               {vista_valida, vista_tentativa, latidos, consistente}

            :procesa_situacion_servidores ->
                if (length(latidos) > 0) do
                    # Se actualizan los latidos (+1)
                    latidos = for i <- latidos, do: {elem(i, 0), elem(i, 1) + 1}

                    # Se comprueba si el primario y/o la copia han caído
                    p_activo = estado(vista_valida.primario, latidos)
                    c_activo = estado(vista_valida.copia, latidos)

                    # Se eliminan los nodos que han caído
                    latidos = borrar_inactivos(latidos)

                    # Si han caído los dos, error, se pierde la consistencia
                    if (p_activo == false && c_activo == false) do
                        # Nueva vista (consistencia perdida)
                        vista_valida = vista_inicial()
                        consistente = false
                        IO.puts("ERROR: Se han perdido el primario y la copia.")
                    else
                        # Si ha caído el primario, promocionar la copia como
                        # primario en la vista tentativa
                        if (p_activo == false) do
                            # Nueva vista
                            vista_tentativa = %{vista_tentativa | num_vista:
                                                vista_tentativa.num_vista + 1}
                            vista_tentativa = %{vista_tentativa |
                                                primario: vista_tentativa.copia}

                            if (length(latidos) > 1) do
                                vista_tentativa = %{vista_tentativa | copia:
                                                elem(Enum.at(latidos, 1), 0)}
                            else
                                vista_tentativa = %{vista_tentativa |
                                                    copia: :undefined}
                                IO.puts("AVISO: No hay copia.")
                            end
                        end

                        # Si ha caído la copia, promocionar una nueva copia de
                        # la lista de latidos
                        if (c_activo == false) do
                            # Nueva vista
                            vista_tentativa = %{vista_tentativa | num_vista:
                                                vista_tentativa.num_vista + 1}

                            if (length(latidos) > 1) do
                                vista_tentativa = %{vista_tentativa | copia:
                                                elem(Enum.at(latidos, 1), 0)}
                            else
                                vista_tentativa = %{vista_tentativa |
                                                    copia: :undefined}
                                IO.puts("AVISO: No hay copia.")
                            end
                        end
                    end
                end
                # Return estado
                {vista_valida, vista_tentativa, latidos, consistente}
        end
        bucle_recepcion(vista_valida, vista_tentativa, latidos, consistente)
    end

    # OTRAS FUNCIONES PRIVADAS VUESTRAS

    # Devuelve true si el nodo está activo o indefinido, y false en otro caso
    defp estado(nodo, [latido | latidos]) do
        if (nodo == :undefined) do
            true
        else
            if (length([latido | latidos]) == 0) do
                false
            else
                if (elem(latido, 0) == nodo) do
                    if (elem(latido, 1) > latidos_fallidos()) do
                        false
                    else
                        true
                    end
                else
                    if (length(latidos) > 0) do
                        estado(nodo, latidos)
                    else
                        false
                    end
                end
            end
        end
    end

    # Devuelve los latidos de los nodos activos
    defp borrar_inactivos([latido | latidos]) do
        if (elem(latido, 1) <= latidos_fallidos()) do
            if (length(latidos) > 0) do
                [latido] ++ borrar_inactivos(latidos)
            else
                [latido]
            end
        else
            if (length(latidos) > 0) do
                borrar_inactivos(latidos)
            else
                []
            end
        end
    end
end
