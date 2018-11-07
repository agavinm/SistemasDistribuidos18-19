# AUTOR: Andrés Gavín Murillo y Borja Aguado
# NIAs: 716358 y 741440
# FICHERO: escenario3.exs
# FECHA: 20 de octubre de 2018
# TIEMPO: 1h
# DESCRIPCIÓN: código para el servidor que resuelve el escenario 3

# Servidor distribuido (Atiende más de una petición cada segundo [cada una en un thread de un worker distinto])

defmodule Perfectos do

  defp suma_divisores_propios(n, 1) do
    1
  end

  defp suma_divisores_propios(n, i) when i > 1 do
    if rem(n, i)==0, do: i + suma_divisores_propios(n, i - 1), else: suma_divisores_propios(n, i - 1)
  end

  def suma_divisores_propios(n) do
    suma_divisores_propios(n, n - 1)
  end

  def es_perfecto?(1) do
    false
  end

  def es_perfecto?(a) when a > 1 do
    suma_divisores_propios(a) == a
  end

  defp encuentra_perfectos({a, a}, queue) do
    if es_perfecto?(a), do: [a | queue], else: queue
  end
  defp encuentra_perfectos({a, b}, queue) when a != b do
    encuentra_perfectos({a, b - 1}, (if es_perfecto?(b), do: [b | queue], else: queue))
  end

  def encuentra_perfectos({a, b}) do
    encuentra_perfectos({a, b}, [])
  end

  # Pre: [w_pid|tail] = lista de workers disponibles
  # Post: Envía a los workers la carga de trabajo
  def servidor([w_pid|tail]) do
    receive do
      {pid, :perfectos} -> 		Node.spawn(w_pid, fn ->
                    time1 = :os.system_time(:millisecond)
      							perfectos = encuentra_perfectos({1, 10000})
      							time2 = :os.system_time(:millisecond)
      							send(pid, {time2 - time1, perfectos})
                  end)
      {pid, :perfectos_ht} ->	time1 = :os.system_time(:millisecond)
      							if :rand.uniform(100)>60, do: Process.sleep(round(:rand.uniform(100)/100 * 2000))
								perfectos = encuentra_perfectos({1, 10000})
								time2 = :os.system_time(:millisecond)
								send(pid, {time2 - time1, perfectos})
    end
    servidor(tail++[w_pid])
  end

  # Pre: Máquinas workers conectadas a la máquina master por medio de Node.connect("master")
  # Post: Lanza el servidor que usará a los workers para repartir el trabajo
  def master() do
    servidor(Node.list())
  end
end

pid = spawn(Perfectos, :master, [])
