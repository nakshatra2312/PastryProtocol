defmodule Project3 do
  alias Pastry.Crypto
  alias Pastry.Supervisor
  
  def main(args \\ []) do
    send self(), {:terminate}    
    args
    |> parse_string
    
    receive do      
      {:terminate, _} -> 
        #IO.inspect message
    end    
  end

  def parent_listener(num_nodes, main_pid, ho, count) do
    if num_nodes > 0 do
      receive do      
        {:message, message, hops} -> 
          {:ok, file} = File.open "output.txt", [:append]
          #IO.inspect message
          IO.binwrite file, "#{message} \n"
          File.close file 
          parent_listener(num_nodes - 1, main_pid, ho + hops, count)
      end
    else
      average = ho/count
      IO.inspect "Total Hops Average Count: #{average}"
      send main_pid, {:terminate, "OK"}
    end
  end  

  def individual_node_listener(start_node, num_request, parent_listener_id, hops, count) do
    if(num_request > 0) do
      receive do
        { :message, message, hop_count } -> 

          {:ok, file} = File.open "output.txt", [:append]
          #IO.inspect "Start: #{start_node}  #{message} Hop: #{hop_count}"
          IO.binwrite file, "Start: #{start_node}  #{message} Hop: #{hop_count} \n"
          File.close file
          hops = hops + hop_count
          individual_node_listener(start_node, num_request - 1, parent_listener_id, hops, count)
      end
    else
        average_hop_count = hops/count
        send parent_listener_id, {:message, "Terminate: #{start_node} after Hops: #{average_hop_count}", hops}
    end
  end

  defp parse_string(args) do  
    num_nodes =  String.to_integer(Enum.at(args,0))
    #IO.inspect num_nodes
    num_request =  String.to_integer(Enum.at(args,1))
    #IO.inspect num_request    
    global_map = generate_nodes(0, num_nodes, %{})    
    #IO.inspect global_map
    #IO.inspect map_size(global_map)
    global_map = convert_list_to_tuple(global_map)
    #IO.inspect global_map
    #{:ok, file} = File.open "hashmap.txt", [:write] 
    #File.write! "encoded.txt", :erlang.term_to_binary(global_map)
    #Enum.each global_map, fn {key, value} -> IO.write(file, inspect("#{key} -- ")) end        
    
    #IO.write(file, Map.to_list(global_map))
    #File.close file
    
    {:ok, _} = Supervisor.start_link
    add_nodes(0, num_nodes, global_map) 
    main_pid = self()
    parent_listener_id = spawn fn -> parent_listener(num_nodes, main_pid, 0, num_nodes * num_request) end
    spawn fn -> start_sending_message(0, num_nodes, num_request, parent_listener_id) end
  end

  defp start_sending_message(index, num_nodes, num_request, parent_listener_id) do    
    if index < num_nodes do      
      start_node = Crypto.md5(to_string(index)) 
      start = :"#{start_node}"
      
      listener_pid = spawn fn -> individual_node_listener(start, num_request, parent_listener_id, 0, num_request) end
      pick_random_destination(start, num_nodes, num_request, listener_pid)      
      start_sending_message(index + 1, num_nodes, num_request, parent_listener_id)
    end
  end

  defp pick_random_destination(start_node, num_nodes, num_request, listener_pid) do
    if num_request > 0 do
      rand = Enum.random(0..num_nodes-1)
      final_node = Crypto.md5(to_string(rand))
      final = :"#{final_node}"
      GenServer.cast(start_node, {:receive, "hello", final, 0, listener_pid})
      pick_random_destination(start_node, num_nodes, num_request - 1, listener_pid)
    end
  end  

  defp convert_list_to_tuple(global_map) do
    for {key, value} <- global_map, into: %{}, do: {key, List.to_tuple(value)}       
  end

  def generate_nodes(count, num_nodes, global_map) do
    if count < num_nodes do
      node_Id = Crypto.md5(to_string(count))      
      global_map = update_global_map(0, node_Id, global_map)      
      generate_nodes(count + 1, num_nodes, global_map)
    else
      global_map
    end
  end

  def update_global_map(count, node_Id, global_map) do
    if count < String.length(node_Id) do
      substring = String.slice(node_Id, 0..count)
      if Map.has_key?(global_map, substring) do
        list = Map.get(global_map, substring)
        global_map = Map.replace(global_map, substring, list ++ [node_Id])
      else
        global_map = Map.put(global_map, substring, [node_Id])
      end
      update_global_map(count + 1, node_Id, global_map)
    else
      global_map
    end
  end

  defp add_nodes(index, num_nodes, global_map) do
    if index < num_nodes do
      node_Id = Crypto.md5(to_string(index))     
      neighbours_map = hex_decode(0, "", String.slice(node_Id, 0..0), %{}, global_map) 
      #IO.inspect neighbours_map
      neighbours_map = determine_neighbours(0, node_Id, neighbours_map, global_map)     
      
      Supervisor.add_children(node_Id, neighbours_map)      
      add_nodes(index + 1, num_nodes, global_map)      
    end
  end

  defp determine_neighbours(index, node_Id, neighbour_map, global_map) do
    if index < String.length(node_Id) - 1 do
      prefix = String.slice(node_Id, 0..index)
      char = String.slice(node_Id, index+1..index+1)
      neighbour_map = hex_decode(0, prefix, char, neighbour_map, global_map)

      determine_neighbours(index + 1, node_Id, neighbour_map, global_map)
    else
      neighbour_map
    end
  end

  defp hex_decode(index, prefix, char, map, global_map) do    
    if index <= 9 do
      ind = index + 30
      temp = elem(Base.decode16(to_string(ind)), 1)
      #IO.puts "#{char} #{temp}"
      if temp != char do
        key ="#{prefix}#{temp}"    
        #IO.inspect global_map   
        if Map.has_key?(global_map, key) do
          #IO.puts "inn"
          neigh_tuple = Map.get(global_map, key)          
          random_neigh = elem(neigh_tuple, Enum.random(0..tuple_size(neigh_tuple)-1))
          #IO.inspect random_neigh
          map = Map.put(map, key, random_neigh)  
          hex_decode(index + 1, prefix, char, map, global_map)  
        else
          hex_decode(index + 1, prefix, char, map, global_map)      
        end
      else
        hex_decode(index + 1, prefix, char, map, global_map)
      end      
    else
      if index <= 15 do
        ind = index + 31
        temp = elem(Base.decode16(to_string(ind)), 1)
        #IO.puts "#{char} #{temp}"
        if temp != char do
          key ="#{prefix}#{temp}"
          #IO.inspect key
          if Map.has_key?(global_map, key) do
            #IO.puts "hiehdidcdcdhif"
            neigh_tuple = Map.get(global_map, key)
            random_neigh = elem(neigh_tuple, Enum.random(0..tuple_size(neigh_tuple)-1))
            map = Map.put(map, key, random_neigh)
            hex_decode(index + 1, prefix, char, map, global_map)
          else
            hex_decode(index + 1, prefix, char, map, global_map)
          end
        else
          hex_decode(index + 1, prefix, char, map, global_map)
        end     
      else
        map
      end
    end    
  end

end
