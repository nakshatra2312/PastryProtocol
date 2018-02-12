defmodule Pastry.Supervisor do
    use Supervisor
    alias Pastry.Node

    def start_link do        
        Supervisor.start_link(__MODULE__, [],  name: :pastry_supervisor)       
    end

    def init(_) do
        children = 
        [            
            worker(Node, []),                        
        ]        
        supervise(children, strategy: :simple_one_for_one)        
    end

    def add_children(node_Id, neighbours) do
        args = [node_Id, neighbours]        
        Supervisor.start_child(:pastry_supervisor, [args])
    end

end
