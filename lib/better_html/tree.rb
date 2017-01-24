require 'erubis/engine/eruby'
require 'html_tokenizer'

module BetterHtml
  class Tree
    attr_reader :nodes

    def initialize(document)
      @document = document
      @erb = BetterHtml::Tree::ERB.new(@document)
      @nodes = parse!
    end

    private

    def parse!
      nodes = []
      tokens = @erb.tokens.dup
      while token = tokens[0]
        case token.type
        when :cdata_start
          tokens.shift
          nodes << consume_cdata(tokens)
        when :comment_start
          tokens.shift
          nodes << consume_comment(tokens)
        when :tag_start
          tokens.shift
          nodes << consume_tag(tokens)
        when :text, :stmt, :expr_literal, :expr_escaped
          nodes << consume_text(tokens)
        else
          raise RuntimeError, "Unhandled token #{token.type}"
        end
      end
      nodes
    end

    def consume_cdata(tokens)
      node = CData.new
      while tokens.any? && tokens[0].type != :cdata_end
        node.content << tokens.shift
      end
      tokens.shift if tokens.any? && tokens[0].type == :cdata_end
      node
    end

    def consume_comment(tokens)
      node = Comment.new
      while tokens.any? && tokens[0].type != :comment_end
        node.content << tokens.shift
      end
      tokens.shift if tokens.any? && tokens[0].type == :comment_end
      node
    end

    def consume_tag(tokens)
      node = Tag.new
      if tokens.any? && tokens[0].type == :solidus
        tokens.shift
        node.closing = true
      end
      while tokens.any? && [:tag_name, :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.name << tokens.shift
      end
      while tokens.any?
        token = tokens[0]
        if token.type == :attribute_name
          node.attributes << consume_attribute(tokens)
        elsif token.type == :attribute_quoted_value_start
          node.attributes << consume_attribute_value(tokens)
        elsif token.type == :tag_end
          tokens.shift
          break
        else
          tokens.shift
        end
      end
      node
    end

    def consume_attribute(tokens)
      node = Attribute.new
      while tokens.any? && [:attribute_name, :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.name << tokens.shift
      end
      return node unless consume_equal?(tokens)
      while tokens.any? && [
          :attribute_quoted_value_start, :attribute_quoted_value,
          :attribute_quoted_value_end, :attribute_unquoted_value,
          :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.value << tokens.shift
      end
      node
    end

    def consume_equal?(tokens)
      while tokens.any? && [:whitespace, :equal].include?(tokens[0].type)
        return true if tokens.shift.type == :equal
      end
      false
    end

    def consume_text(tokens)
      node = Text.new
      while tokens.any? && [:text, :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.content << tokens.shift
      end
      node
    end

    class ERB < ::Erubis::Eruby
      attr_reader :tokens

      def initialize(document)
        @parser = HtmlTokenizer::Parser.new
        @tokens = []
        super
      end

      def add_text(src, text)
        @parser.parse(text) { |*args| add_tokens(*args) }
      end

      def add_stmt(src, code)
        text = "<%#{code}%>"
        start = @parser.document_length
        stop = start + text.size
        @tokens << Token.new(
          type: :stmt,
          code: code,
          text: text,
          location: Location.new(start, stop, @parser.line_number, @parser.column_number)
        )
        @parser.append_placeholder(text)
      end

      def add_expr_literal(src, code)
        text = "<%=#{code}%>"
        start = @parser.document_length
        stop = start + text.size
        @tokens << Token.new(
          type: :expr_literal,
          code: code,
          text: text,
          location: Location.new(start, stop, @parser.line_number, @parser.column_number)
        )
        @parser.append_placeholder(text)
      end

      def add_expr_escaped(src, code)
        text = "<%==#{code}%>"
        start = @parser.document_length
        stop = start + text.size
        @tokens << Token.new(
          type: :expr_escaped,
          code: code,
          text: text,
          location: Location.new(start, stop, @parser.line_number, @parser.column_number)
        )
        @parser.append_placeholder(text)
      end

      private

      def add_tokens(type, start, stop, line, column)
        @tokens << Token.new(
          type: type,
          text: @parser.extract(start, stop),
          location: Location.new(start, stop, line, column)
        )
      end
    end

    class Token < OpenStruct
    end

    class Location
      attr_accessor :start, :stop, :line, :column

      def initialize(start, stop, line, column)
        @start = start
        @end = stop
        @line = line
        @column = column
      end
    end

    class Tag
      attr_accessor :name
      attr_accessor :attributes
      attr_accessor :closing

      def initialize
        @name = []
        @attributes = []
      end

      def closing?
        closing
      end

      def find_attr(wanted)
        @attributes.each do |attribute|
          name = attribute.name.map(&:text).join
          return attribute if name == wanted
        end
        nil
      end
    end

    class Attribute
      attr_accessor :name
      attr_accessor :value

      def initialize
        @name = []
        @value = []
      end
    end

    class ContentNode
      attr_accessor :content

      def initialize
        @content = []
      end
    end

    class CData < ContentNode
    end

    class Comment < ContentNode
    end

    class Text < ContentNode
    end
  end
end