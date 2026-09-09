# frozen_string_literal: true

ProgramNode = Data.define(:statements)

VarDeclNode = Data.define(:type_token, :name_token, :expression)

AssignNode = Data.define(:name_token, :expression)

BinaryOpNode = Data.define(:left, :operator_token, :right)

IdentifierNode = Data.define(:token)

NumberNode = Data.define(:token)

StringNode = Data.define(:token)