# Ejecución del chat distribuido en 3 máquinas

1a. iex --name nodo1@ip1 --cookie ssdd
2a. iex --name nodo2@ip2 --cookie ssdd
3a. iex --name nodo3@ip3 --cookie ssdd

1ba. Node.connect(:"nodo2@ip2")
1bb. Node.connect(:"nodo3@ip3")
2b.  Node.connect(:"nodo3@ip3")

c. Copiar los códigos

1d. Chat.main(1, [:"nodo1@ip1", :"nodo2@ip2", :"nodo3@ip3"])
2d. Chat.main(2, [:"nodo1@ip1", :"nodo2@ip2", :"nodo3@ip3"])
3d. Chat.main(3, [:"nodo1@ip1", :"nodo2@ip2", :"nodo3@ip3"])

