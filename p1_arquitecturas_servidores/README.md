# Arquitecturas cliente servidor

1. iex --name nodo1@127.0.0.1 --cookie ssdd
2. iex --name nodo2@127.0.0.1 --cookie ssdd

3. iex(nodo1@127.0.0.1)1> Process.register(self(), :server)

4. iex(nodo1@127.0.0.1)3> Node.connect(:"nodo2@127.0.0.1")

5. copiar los codigos y ejecutar

6. server: Perfectos.servidor()

7. cliente: Perfectos_cliente.cliente({:server, :"nodo1@127.0.0.1"}, :uno)




------------------

n = número de cores de cada máquina

[Total] Máquinas del laboratorio = 4 cores

Escenario 1:
 Cliente: Lanza 1 petición cada 2 segundos. [Total: 1 petición cada 2 segundos]
 Servidor: Atiende 1 petición cada 1 segundo. [Total: 2 peticiones cada 2 segundos]
 
Escenario 2:
 Cliente: Lanza n peticiones cada 2 segundos. [Total: 4 peticiones cada 2 segundos]
 Servidor: Atiende n-1 peticiones cada 1 segundo (ya que 1 core es el "master"). [Total: 6 peticiones cada 2 segundos]
 
Escenario 3:
 Cliente: Lanza n*2 + 2 peticiones cada 2 segundos. [Total: 10 peticiones cada 2 segundos]
 Servidor: Atiende n*2 - 1 peticiones cada 1 segundo (ya que 1 core es el "master"). [Total: 14 peticiones cada 2 segundos]
  Máquina1: Atiende n-1 peticiones cada 1 segundo (ya que 1 core es el "master").
  Máquina2: Atiende n peticiones cada 1 segundo.

Escenario 4:
 Cliente: Lanza n*2 + 2 peticiones cada 2 segundos. [Total: 10 peticiones cada 2 segundos]
 Servidor: Atiende n*4 - 1 peticiones cada 3 segundos (o menos) (ya que 1 core es el "master"). [Total: 15 peticiones cada 3 segundos]
  Máquina1: Atiende n-1 peticiones cada 3 segundos (ya que 1 core es el "master").
  Máquina2: Atiende n peticiones cada 3 segundos.
  Máquina3: Atiende n peticiones cada 3 segundos.
  Máquina4: Atiende n peticiones cada 3 segundos.
