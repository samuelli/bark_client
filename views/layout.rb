module App
  module Views
    class Layout < Mustache
      def title 
        @title || "Checkin"
      end
    end
  end
end
