# frozen_string_literal: true
ProgramNode = Data.define(:declarations)
FunctionDefNode = Data.define(:return_type, :name_token, :params, :body)
BlockNode = Data.define(:statements)
VarDeclNode = Data.define(:type_token, :name_token, :expression) # :expression pode ser nil
AssignNode = Data.define(:target, :expression)

BinaryOpNode = Data.define(:left, :operator_token, :right)
IdentifierNode = Data.define(:token)
NumberNode = Data.define(:token)
StringNode = Data.define(:token)

IfNode = Data.define(:condition, :then_branch, :else_branch)
WhileNode = Data.define(:condition, :body)
ReturnNode = Data.define(:expression)

class Parser
    def initialize(tokens)
        @tokens = tokens + [build_eof_(tokens)]
        @pos = 0
        @errors = []
    end

    def peek = @tokens[@pos]

        def at_end? = peek.type == :EOF

    def advance
        token = peek
        @pos += 1 unless at_end?
        token
    end

    def check?(type) = peek.type == type
    

    private 

    def build_eof_(tokens)
        last = tokens.last
        return Token.new(:EOF, '', 1,1) if last.nil?

        token = Token.new(:EOF, '', last.line, last.column + last.lexeme.to_s.length)
    end 
end
