# frozen_string_literal: true

require_relative '../src/lexer'
require_relative '../src/parser'

GREEN  = "\e[32m"
RED    = "\e[31m"
BLUE   = "\e[34m"
YELLOW = "\e[33m"
RESET  = "\e[0m"

$falhas = 0

def assert(condition, message)
  if condition
    puts "  #{GREEN}✔#{RESET} #{message}"
  else
    puts "  #{RED}✖ [FALHA]#{RESET} #{message}"
    $falhas += 1
  end
end

def parse_code(source)
  lexer = Lexer.new(source)
  Parser.new(lexer.tokens)
end

puts "#{BLUE}================================================================#{RESET}"
puts "#{BLUE}  SAFIRA — Testes Unitários do Parser (src/parser.rb)           #{RESET}"
puts "#{BLUE}================================================================#{RESET}\n"

# [1] Declarações simples, inicializadas e múltiplas
puts "#{YELLOW}[1] Declarações de Variáveis (Simples, Inicializada e Múltipla)#{RESET}"
p1 = parse_code("int x;\nfloat y = 2.5;\nint a, b = 10;")
ast1 = p1.parse

assert(p1.valid?, 'Nenhum erro sintático nas declarações válidas')
assert(ast1.is_a?(ProgramNode), 'parse devolve um ProgramNode')
assert(ast1.declarations.size == 4, "Total de 4 VarDeclNode gerados (obtido: #{ast1.declarations.size})")

decl_x, decl_y, decl_a, decl_b = ast1.declarations
assert(decl_x.is_a?(VarDeclNode) && decl_x.name_token.lexeme == 'x' && decl_x.expression.nil?,
       "'int x;' gera VarDeclNode com expression nil")
assert(decl_y.is_a?(VarDeclNode) && decl_y.type_token.lexeme == 'float' && decl_y.expression.is_a?(NumberNode),
       "'float y = 2.5;' gera VarDeclNode com NumberNode")
assert(decl_a.name_token.lexeme == 'a' && decl_a.expression.nil? &&
       decl_b.name_token.lexeme == 'b' && decl_b.expression.is_a?(NumberNode),
       "'int a, b = 10;' expande em dois VarDeclNode preservando o tipo 'int'")

# [2] Atribuições e Literais (NumberNode, StringNode, CharNode, IdentifierNode)
puts "\n#{YELLOW}[2] Atribuições e Nós de Literais#{RESET}"
p2 = parse_code(%(char c = 'M';\ntexto = "safira";\nx = c;))
ast2 = p2.parse

assert(p2.valid?, 'Nenhum erro sintático nas atribuições com literais')
decl_c, assign_str, assign_id = ast2.declarations
assert(decl_c.expression.is_a?(CharNode) && decl_c.expression.token.lexeme == "'M'",
       "Literal 'M' gera CharNode")
assert(assign_str.is_a?(AssignNode) && assign_str.target.lexeme == 'texto' && assign_str.expression.is_a?(StringNode),
       'Atribuição de string gera AssignNode com StringNode')
assert(assign_id.is_a?(AssignNode) && assign_id.expression.is_a?(IdentifierNode),
       'Atribuição com variável à direita gera IdentifierNode')

# [3] Precedência de Operadores (* / % antes de + -)
puts "\n#{YELLOW}[3] Precedência Matemática (* / % antes de + -)#{RESET}"
p3 = parse_code('x = a + b * c;')
expr3 = p3.parse.declarations.first.expression

assert(p3.valid?, "Expressão 'a + b * c' é válida")
assert(expr3.is_a?(BinaryOpNode) && expr3.operator_token.lexeme == '+',
       "Raiz de 'a + b * c' é o operador '+'")
assert(expr3.left.is_a?(IdentifierNode) && expr3.left.token.lexeme == 'a',
       "Lado esquerdo de '+' é 'a'")
assert(expr3.right.is_a?(BinaryOpNode) && expr3.right.operator_token.lexeme == '*',
       "Lado direito de '+' é a subárvore 'b * c'")

# [4] Associatividade à Esquerda e Parênteses
puts "\n#{YELLOW}[4] Associatividade à Esquerda e Agrupamento com Parênteses#{RESET}"
p4_assoc = parse_code('x = a - b - c;')
expr_assoc = p4_assoc.parse.declarations.first.expression

assert(expr_assoc.operator_token.lexeme == '-' &&
       expr_assoc.left.is_a?(BinaryOpNode) &&
       expr_assoc.left.left.token.lexeme == 'a' &&
       expr_assoc.left.right.token.lexeme == 'b' &&
       expr_assoc.right.token.lexeme == 'c',
       "'a - b - c' agrupa à esquerda como '(a - b) - c'")

p4_paren = parse_code('x = (a + b) * c % 2;')
expr_paren = p4_paren.parse.declarations.first.expression

assert(p4_paren.valid?, "Expressão '(a + b) * c % 2' é válida")
assert(expr_paren.operator_token.lexeme == '%' &&
       expr_paren.left.operator_token.lexeme == '*' &&
       expr_paren.left.left.operator_token.lexeme == '+',
       "Parênteses sobrepõem a precedência padrão: '((a + b) * c) % 2'")

# [5] Detecção de Erros Sintáticos e Posição Exata
puts "\n#{YELLOW}[5] Detecção de Erros Sintáticos (Falta de ';', Expressão Vazia, Parêntese)#{RESET}"
p5_semi = parse_code('int x = 5')
p5_semi.parse
assert(!p5_semi.valid? && p5_semi.errors.size == 1, "Falta de ';' gera 1 ParseError")
assert(p5_semi.errors.first.message.include?("Esperado ';'"), "Mensagem indica falta de ';'")

p5_empty = parse_code('x = ;')
p5_empty.parse
assert(!p5_empty.valid? && p5_empty.errors.first.column == 5,
       "Expressão vazia 'x = ;' aponta erro na coluna 5 (obtido: #{p5_empty.errors.first.column})")

p5_paren = parse_code('x = (a + b;')
p5_paren.parse
assert(!p5_paren.valid? && p5_paren.errors.first.message.include?("Esperado ')'"),
       "Parêntese não fechado reporta falta de ')'")

# [6] Recuperação em Modo Pânico (Múltiplos Erros sem Traceback)
puts "\n#{YELLOW}[6] Recuperação em Modo Pânico e Resiliência#{RESET}"
broken_code = <<~C
  int a = ;
  x = 10 + * 20;
  int valido = 42;
  = ; ) (
C

p6 = parse_code(broken_code)
ast6 = p6.parse

assert(!p6.valid? && p6.errors.size >= 3,
       "Múltiplos erros acumulados em uma única execução (obtido: #{p6.errors.size})")
assert(ast6.declarations.any? { |d| d.is_a?(VarDeclNode) && d.name_token.lexeme == 'valido' },
       "Comando válido entre linhas com erro ('int valido = 42;') ainda é incluído na AST")

p6_empty = parse_code('')
assert(p6_empty.valid? && p6_empty.parse.declarations.empty?,
       'Arquivo vazio devolve ProgramNode vazio e válido')

# [7] Validação dos Arquivos em samples/
puts "\n#{YELLOW}[7] Integração com Arquivos de Exemplo (samples/*.c)#{RESET}"
%w[valid.c err_type.c err_scope.c].each do |sample|
  path = File.expand_path("../samples/#{sample}", __dir__)
  code = File.read(path)
  lexer = Lexer.new(code)
  parser = Parser.new(lexer.tokens)
  parser.parse
  assert(lexer.valid? && parser.valid?, "samples/#{sample} passa nas análises léxica e sintática")
end

# [8] Atribuições compostas
puts "\n#{YELLOW}[8] Atribuições Compostas (+=, -=, *=, /= e %=)#{RESET}"
p8 = parse_code('i += 2; i -= 3 + 4; i *= 5; i /= 6; i %= 7;')
sum_assignment, sub_assignment, mult_assignment, div_assignment, mod_assignment = p8.parse.declarations
assert(p8.valid?, '+=, -=, *=, /= e %= são aceitos como comandos')
assert(sum_assignment.is_a?(AssignNode) && sum_assignment.target.lexeme == 'i' &&
       sum_assignment.expression.is_a?(BinaryOpNode) &&
       sum_assignment.expression.left.token.lexeme == 'i' &&
       sum_assignment.expression.operator_token.type == :OP_SOMA &&
       sum_assignment.expression.operator_token.lexeme == '+' &&
       sum_assignment.expression.right.token.lexeme == '2',
       'i += 2 gera a estrutura de i = i + 2')
assert(sub_assignment.expression.operator_token.type == :OP_SUB &&
       sub_assignment.expression.operator_token.lexeme == '-' &&
       sub_assignment.expression.right.is_a?(BinaryOpNode) &&
       sub_assignment.expression.right.operator_token.lexeme == '+',
       'i -= 3 + 4 preserva o agrupamento i = i - (3 + 4)')
assert(mult_assignment.expression.operator_token.type == :OP_MULT &&
       mult_assignment.expression.operator_token.lexeme == '*' &&
       mult_assignment.expression.right.token.lexeme == '5',
       'i *= 5 gera a estrutura de i = i * 5')
assert(div_assignment.expression.operator_token.type == :OP_DIV &&
       div_assignment.expression.operator_token.lexeme == '/' &&
       div_assignment.expression.right.token.lexeme == '6',
       'i /= 6 gera a estrutura de i = i / 6')
assert(mod_assignment.expression.operator_token.type == :OP_MOD &&
       mod_assignment.expression.operator_token.lexeme == '%' &&
       mod_assignment.expression.right.token.lexeme == '7',
       'i %= 7 gera a estrutura de i = i % 7')
p8_for = parse_code('for (int i = 0; i < 10; i += 2) { i %= 3; }')
assert(p8_for.valid? && p8_for.parse.declarations.first.update.is_a?(AssignNode),
       'Atribuição composta também é aceita no passo do for')
p8_invalid = parse_code('i += ; int valido = 1;')
assert(!p8_invalid.valid? && p8_invalid.parse.declarations.any? { |node| node.is_a?(VarDeclNode) },
       'Expressão ausente após += gera erro e preserva o comando seguinte')

# [9] Pré-incremento como comando e no cabeçalho do for
puts "\n#{YELLOW}[9] Pré-incremento (++i)#{RESET}"
p9 = parse_code('++i; i++;')
prefix, postfix = p9.parse.declarations
assert(p9.valid? && [prefix, postfix].all? { |node| node.is_a?(IncDecNode) },
       'Pré e pós-incremento são aceitos como comandos')
assert(prefix.target.lexeme == 'i' && prefix.operator_token.lexeme == '++' &&
       prefix.operator_token.column < prefix.target.column,
       'Pré-incremento preserva o alvo e a posição do operador')
p9_for = parse_code('for (++i; i < 10; ++i) { i += 1; }')
assert(p9_for.valid? && p9_for.parse.declarations.first.update.is_a?(IncDecNode),
       'Pré-incremento é aceito na inicialização e no passo do for')
p9_invalid = parse_code('++2; int valido = 1;')
assert(!p9_invalid.valid? && p9_invalid.errors.first.message.include?('Esperado identificador') &&
       p9_invalid.parse.declarations.any? { |node| node.is_a?(VarDeclNode) },
       'Incremento de literal é rejeitado e a análise continua')
p9_missing = parse_code("++i\nint valido = 1;")
assert(!p9_missing.valid? && p9_missing.errors.first.message.include?("'++i'"),
       'Falta de ponto e vírgula descreve o pré-incremento na ordem correta')

# [10] Pré-decremento como comando e no cabeçalho do for
puts "\n#{YELLOW}[10] Pré-decremento (--i)#{RESET}"
p10 = parse_code('--i; for (--i; i > 0; --i) { i--; }')
decrement, loop_node = p10.parse.declarations
assert(p10.valid? && decrement.is_a?(IncDecNode) &&
       decrement.target.lexeme == 'i' && decrement.operator_token.type == :OP_DEC,
       'Pré-decremento é aceito como comando')
assert(p10.valid? && loop_node.is_a?(ForNode) &&
       [loop_node.init.first, loop_node.update].all? { |node| node.is_a?(IncDecNode) && node.operator_token.type == :OP_DEC },
       'Pré-decremento é aceito na inicialização e no passo do for')
p10_invalid = parse_code('--2;')
assert(!p10_invalid.valid? && p10_invalid.errors.first.message.include?('Esperado identificador'),
       'Pré-decremento exige um identificador')

puts
if $falhas.zero?
  puts "#{GREEN}================================================================#{RESET}"
  puts "#{GREEN}  TODOS OS TESTES UNITÁRIOS DO PARSER FORAM APROVADOS COM SUCESSO!#{RESET}"
  puts "#{GREEN}================================================================#{RESET}"
else
  puts "#{RED}================================================================#{RESET}"
  puts "#{RED}  #{$falhas} verificação(ões) falharam.#{RESET}"
  puts "#{RED}================================================================#{RESET}"
  exit 1
end
