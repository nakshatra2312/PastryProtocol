defmodule Pastry.Node do
    use GenServer 

    def start_link(args \\ []) do   
        node_Id = Enum.at(args,0) 
        node_Id = :"#{node_Id}"       
        neighbours_map = Enum.at(args,1)       
        GenServer.start_link(__MODULE__, [neighbours_map, node_Id], name: node_Id)  
    end

    def handle_cast({:receive, message, final_node, hop_count, listener_pid}, state) do        
        neighbours_map = Enum.at(state, 0)        
        match_prefix = prefix_matching(0, "", neighbours_map, to_string(final_node))

        #IO.inspect "Prefix: #{match_prefix}"
        #IO.inspect neighbours_map
        if String.length(match_prefix) > 0 do
            neighbour_node = Map.get(neighbours_map, match_prefix)
            neighbour_name = :"#{neighbour_node}"
 
            #IO.inspect "Message Received: #{neighbour_name}"
            GenServer.cast(neighbour_name, {:receive, message, final_node, hop_count + 1, listener_pid})
        else          
            node_Id = Enum.at(state, 1)
            send listener_pid, {:message, "Final: #{final_node} Found: #{node_Id}", hop_count}
        end
        {:noreply, state}
    end     
    
    defp prefix_matching(index, matched_prefix, neighbours_map, final_node) do
        if index < String.length(final_node) do
            substring = String.slice(final_node, 0..index)
            if Map.has_key?(neighbours_map, substring) do
                prefix_matching(index + 1, substring, neighbours_map, final_node)
            else
                prefix_matching(index + 1, matched_prefix, neighbours_map, final_node)
            end
        else            
            matched_prefix
        end
    end

end