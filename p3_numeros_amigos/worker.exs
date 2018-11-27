# AUTOR: Andrés Gavín Murillo y Borja Aguado
# NIAs: 716358 y 741440
# FICHERO: worker.exs
# FECHA: noviembre de 2018
# TIEMPO: 25 horas
# DESCRIPCIÓN: Código de los workers

defmodule Worker do
  defp init do
    case :random.uniform(100) do
      random when random > 80 -> :crash
      random when random > 50 -> :omission
      random when random > 25 -> :timing
      _ -> :no_fault
    end
  end

  def loop(worker_type) do
    loopI(worker_type, init())
  end

  def worker1(name) do
    Process.register(self(), name)
    loopI(:divisores, init())
  end

  def worker2(name) do
    Process.register(self(), name)
    loopI(:suma_divisores, init())
  end

  def worker3(name) do
    Process.register(self(), name)
    loopI(:suma_lista, init())
  end

  defp loopI(worker_type, error_type) do
    delay = case error_type do
      :crash -> if :random.uniform(100) > 75, do: :infinity
      :timing -> :random.uniform(100)*1000
      _ ->  0
    end
    Process.sleep(delay)
    result = receive do
     {:req, {m_pid, m}} ->
             #IO.inspect(m, label: "Recived")
             if (((error_type == :omission) and (:random.uniform(100) < 75)) or (error_type ==
                    :timing) or (error_type==:no_fault)) do

                if worker_type == :divisores do
                  result = divisores(m)
                  send(m_pid, {:result, m, result})
                else
                  if worker_type == :suma_divisores do
                    result = suma_divisores(m)
                    send(m_pid, {:result, m, result})
                  else
                    result = suma_lista(m)
                    send(m_pid, {:result, m, result})
                  end

                end
             end
    end
    loopI(worker_type, error_type)
  end

  # Devuelve una lista con los divisores de n
  defp divisores(n) do
    Range.new(1,n) |> Enum.filter(fn x -> rem(n, x) == 0 end)
  end

  # Devuelve la suma de los divisores propios de n
  defp suma_divisores(n) do
    suma_lista(divisores(n)) - n
  end

  # Suma los elementos de una lista m
  defp suma_lista(m) do
    Enum.reduce(m, 0, fn x,acc -> x+acc end)
  end
end
