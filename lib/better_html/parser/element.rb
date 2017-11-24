require_relative 'base'

module BetterHtml
  class Parser
    class Element < Base
      tokenized_attribute :name
      attr_reader :attributes
      attr_accessor :closing, :self_closing
      alias_method :closing?, :closing
      alias_method :self_closing?, :self_closing

      def initialize
        @name_parts = []
        @attributes = []
      end

      def find_attr(wanted)
        @attributes.each do |attribute|
          return attribute if attribute.name == wanted
        end
        nil
      end
      alias_method :[], :find_attr
    end
  end
end