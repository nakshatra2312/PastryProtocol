defmodule Pastry.Crypto do
    
      def md5(input) do
        :crypto.hash(:md5, input) |> Base.encode16
      end
  
  end