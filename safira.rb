# frozen_string_literal: true

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/semantic'

module SafiraCLI
  class Palette
    CODES = {
      green: "\e[32m",
      yellow: "\e[33m",
      red: "\e[31m",
      blue: "\e[34m",
      cyan: "\e[36m",
      bold: "\e[1m",
      dim: "\e[2m",
      reset: "\e[0m"
    }.freeze

    def initialize(enabled: true)
      @enabled = enabled
    end

    def colorize(text, *styles)
      return text.to_s unless @enabled

      prefix = styles.map { |style| CODES[style] }.compact.join
      "#{prefix}#{text}#{CODES[:reset]}"
    end
  end

  class Renderer
    BANNER_LINE  = ('=' * 80).freeze
    SECTION_LINE = ('-' * 80).freeze

    SEMANTIC_TITLES = {
      type_mismatch: 'Incompatibilidade de tipos',
      undeclared_variable: 'Variável não declarada',
      redeclaration: 'Redeclaração de variável',
      invalid_operation: 'Operação inválida',
      invalid_condition: 'Condição inválida',
      invalid_return: 'Retorno inválido',
      invalid_type: 'Tipo inválido'
    }.freeze

    GEM = <<~'ART'.lines.map(&:chomp).freeze
        ______
       /  /\  \
      /__/__\__\
      \  \  /  /
       \  \/  /
        \    /
         \  /
          \/
    ART
    GEM_WIDTH = GEM.map(&:length).max

    def initialize(out: $stdout, palette: Palette.new)
      @out = out
      @palette = palette
    end

    def render_header(file_path)
      @out.puts @palette.colorize(BANNER_LINE, :blue, :bold)
      info = [
        nil,
        nil,
        nil,
        @palette.colorize('SAFIRA COMPILER — Análise de Código C', :bold),
        "Arquivo: #{@palette.colorize(file_path, :cyan)}",
        nil,
        nil,
        nil
      ]

      GEM.each_with_index do |line, idx|
        # ljust antes de colorir para códigos ANSI não afetarem a largura
        art = @palette.colorize(line.ljust(GEM_WIDTH), :cyan, :bold)
        @out.puts "  #{art}   #{info[idx]}".rstrip
      end
      @out.puts @palette.colorize(BANNER_LINE, :blue, :bold)
    end

    def render_footer = @out.puts(@palette.colorize(BANNER_LINE, :blue, :bold))

    def render_tokens(tokens, lexical_errors, source_lines)
      render_section('[1] ANÁLISE LÉXICA: LISTA DE TOKENS')

      if tokens.empty? && lexical_errors.empty?
        @out.puts ' (Nenhum token encontrado)'
      else
        tokens.each { |token| @out.puts " #{token}" }
      end

      return if lexical_errors.empty?

      @out.puts
      lexical_errors.each do |error|
        render_diagnostic(
          tag: 'ERRO LÉXICO',
          title: 'Token inválido',
          line: error.line,
          column: error.column,
          length: error.char.length,
          message: error.message,
          source_lines: source_lines
        )
      end
    end

    def render_symbol_table(symbols)
      render_section('[2] TABELA DE SÍMBOLOS')

      headers = ['Identificador', 'Tipo', 'Linha', 'Ordem Inserção']
      rows = symbols.map { |s| [s.name, s.type || 'indefinido', s.line.to_s, s.order.to_s] }
      widths = [13, 7, 6, 14].each_with_index.map do |min, col|
        ([min] + rows.map { |r| r[col].length }).max
      end

      border = " +-#{widths.map { |w| '-' * w }.join('-+-')}-+"
      format_row = ->(row) { " | #{row.each_with_index.map { |cell, i| cell.ljust(widths[i]) }.join(' | ')} |" }

      @out.puts border, format_row.call(headers), border
      if rows.empty?
        @out.puts " | #{'(Nenhum identificador registrado)'.ljust(widths.sum + 9)} |"
      else
        rows.each { |row| @out.puts format_row.call(row) }
      end
      @out.puts border
    end

    def render_ast(ast, parse_errors, source_lines)
      render_section('[3] ANÁLISE SINTÁTICA: ÁRVORE SINTÁTICA (AST)')

      declarations = ast&.declarations || []
      if declarations.empty? && parse_errors.empty?
        @out.puts ' (Árvore vazia)'
      elsif declarations.any?
        label, children = ast_to_tree(ast)
        @out.puts " #{@palette.colorize(label, :yellow, :bold)}"
        render_tree_children(children, ' ')
      end

      return if parse_errors.empty?

      @out.puts if declarations.any?
      parse_errors.each do |error|
        render_diagnostic(
          tag: 'ERRO SINTÁTICO',
          title: 'Falha gramatical',
          line: error.line,
          column: error.column,
          length: error.lexeme.to_s.length,
          message: error.message,
          source_lines: source_lines
        )
      end
    end

    def render_semantic_skipped(lexical_errors, syntax_errors)
      render_section('[4] ANÁLISE SEMÂNTICA')
      kinds = []
      kinds << 'léxicos' if lexical_errors
      kinds << 'sintáticos' if syntax_errors
      message = " ⚠ Análise semântica não executada: corrija os erros #{kinds.join(' e ')} acima."
      @out.puts @palette.colorize(message, :yellow)
    end

    def render_semantic(semantic_errors, source_lines)
      render_section('[4] ANÁLISE SEMÂNTICA')

      if semantic_errors.empty?
        @out.puts @palette.colorize(' ✔ Nenhuma inconsistência semântica encontrada.', :green, :bold)
        return
      end

      semantic_errors.each_with_index do |error, index|
        title = SEMANTIC_TITLES[error.kind] || 'Inconsistência semântica'
        render_diagnostic(
          tag: 'ERRO SEMÂNTICO',
          title: title,
          line: error.line,
          column: error.column,
          length: error.length,
          message: error.message,
          source_lines: source_lines
        )
        @out.puts if index < semantic_errors.size - 1
      end
    end

    def render_diagnostic(tag:, title:, line:, column:, length:, message:, source_lines:)
      header = " ✖ [#{tag}] #{title} na linha #{line}:"
      @out.puts @palette.colorize(header, :red, :bold)

      code_line = source_lines[line - 1].to_s.chomp
      gutter_width = [line.to_s.length + 5, 6].max
      line_label = line.to_s.rjust(gutter_width)
      blank_gutter = ' ' * gutter_width

      @out.puts "#{line_label} | #{code_line}"

      offset = [column - 1, 0].max
      carets = '^' * [length, 1].max
      pointer = @palette.colorize("#{carets} #{message}", :red)
      @out.puts "#{blank_gutter} | #{' ' * offset}#{pointer}"
    end

    private

    def render_section(title)
      @out.puts
      @out.puts @palette.colorize(title, :yellow, :bold)
      @out.puts @palette.colorize(SECTION_LINE, :dim)
    end

    def render_tree_children(children, prefix)
      children.each_with_index do |(label, subchildren), index|
        last = (index == children.size - 1)
        connector = last ? '└── ' : '├── '
        @out.puts "#{prefix}#{connector}#{label}"
        next_prefix = prefix + (last ? '    ' : '│   ')
        render_tree_children(subchildren, next_prefix)
      end
    end

    def ast_to_tree(node)
      case node
      in ProgramNode[declarations:]
        ['Programa', declarations.map { |decl| ast_to_tree(decl) }]
      in VarDeclNode[type_token:, name_token:, expression:]
        children = [
          ["Tipo (#{type_token.lexeme})", []],
          ["ID (#{name_token.lexeme})", []]
        ]
        children << ast_to_tree(expression) unless expression.nil?
        ['Declaracao', children]
      in AssignNode[target:, expression:]
        ['Atribuicao', [
          ["ID (#{target.lexeme})", []],
          ast_to_tree(expression)
        ]]
      in IncDecNode[target:, operator_token:]
        label = operator_token.lexeme == '++' ? 'Incremento' : 'Decremento'
        ["#{label} (#{operator_token.lexeme})", [["ID (#{target.lexeme})", []]]]
      in FunctionDefNode[return_type:, name_token:, params:, body:]
        children = [["Tipo (#{return_type.lexeme})", []]]
        if params.any?
          param_nodes = params.map do |p|
            ['Parametro', [["Tipo (#{p.type_token.lexeme})", []], ["ID (#{p.name_token.lexeme})", []]]]
          end
          children << ['Parametros', param_nodes]
        end
        children << branch_tree('Corpo', body)
        ["Funcao (#{name_token.lexeme})", children]
      in BlockNode
        branch_tree('Bloco', node)
      in IfNode[keyword:, condition:, then_branch:, else_branch:]
        children = [['Condicao', [ast_to_tree(condition)]], branch_tree('Entao', then_branch)]
        children << branch_tree('Senao', else_branch) unless else_branch.nil?
        ["Condicional (#{keyword.lexeme})", children]
      in WhileNode[keyword:, condition:, body:]
        ["Repeticao (#{keyword.lexeme})", [['Condicao', [ast_to_tree(condition)]], branch_tree('Corpo', body)]]
      in ForNode[keyword:, init:, condition:, update:, body:]
        children = []
        children << ['Inicializacao', init.map { |statement| ast_to_tree(statement) }] if init.any?
        children << ['Condicao', [ast_to_tree(condition)]] unless condition.nil?
        children << ['Passo', [ast_to_tree(update)]] unless update.nil?
        children << branch_tree('Corpo', body)
        ["Repeticao (#{keyword.lexeme})", children]
      in ReturnNode[keyword:, expression:]
        ["Retorno (#{keyword.lexeme})", expression.nil? ? [] : [ast_to_tree(expression)]]
      in BinaryOpNode[left:, operator_token:, right:]
        ["Expressao (#{operator_token.lexeme})", [
          ast_to_tree(left),
          ast_to_tree(right)
        ]]
      in UnaryOpNode[operator_token:, operand:]
        ["Unario (#{operator_token.lexeme})", [ast_to_tree(operand)]]
      in nil
        ['(comando inválido)', []]
      in IdentifierNode[token:]
        ["ID (#{token.lexeme})", []]
      in NumberNode[token:]
        ["NUM (#{token.lexeme})", []]
      in StringNode[token:]
        ["STR (#{token.lexeme})", []]
      in CharNode[token:]
        ["CHAR (#{token.lexeme})", []]
      end
    end

    # Rótulo seguido dos comandos de um bloco, ou do único comando do corpo.
    def branch_tree(label, node)
      case node
      in BlockNode[statements: []]
        [label, [['(vazio)', []]]]
      in BlockNode[statements:]
        [label, statements.map { |statement| ast_to_tree(statement) }]
      else
        [label, [ast_to_tree(node)]]
      end
    end
  end

  class Runner
    SECTION_FLAGS = {
      '--tokens' => :tokens,
      '--symbols' => :symbols,
      '--ast' => :ast,
      '--semantic' => :semantic
    }.freeze

    ALL_SECTIONS = SECTION_FLAGS.values.freeze

    def self.run(argv, out: $stdout, err: $stderr) = new(argv, out: out, err: err).execute

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def execute
      options = parse_options
      return print_usage if options[:help]
      return print_cli_error(options[:error]) if options[:error]

      source = read_source_file(options[:file])
      return 1 if source.nil?

      run_pipeline(options[:file], source, options[:sections], options[:color])
    rescue StandardError => error
      @err.puts error.backtrace if ENV['DEBUG']
      print_cli_error("Falha inesperada ao processar o arquivo: #{error.message}")
    end

    private

    def parse_options
      color = ENV['NO_COLOR'].nil? && !@argv.include?('--no-color')
      @argv.delete('--no-color')

      return { help: true } if @argv.include?('--help') || @argv.include?('-h')

      sections = []
      files = []
      unknown_flags = []

      @argv.each do |arg|
        if SECTION_FLAGS.key?(arg)
          sections << SECTION_FLAGS[arg]
        elsif arg.start_with?('-')
          unknown_flags << arg
        else
          files << arg
        end
      end

      return { error: "Flag desconhecida: #{unknown_flags.first}" } if unknown_flags.any?
      return { error: 'Nenhum arquivo de código-fonte foi informado.' } if files.empty?
      return { error: 'Informe apenas um arquivo de código-fonte por execução.' } if files.size > 1

      {
        file: files.first,
        sections: sections.empty? ? ALL_SECTIONS : sections.uniq,
        color: color
      }
    end

    def read_source_file(file_path)
      File.read(file_path, encoding: 'UTF-8')
    rescue Errno::ENOENT
      print_cli_error("Arquivo não encontrado: '#{file_path}'")
      nil
    rescue Errno::EISDIR
      print_cli_error("O caminho informado é um diretório, não um arquivo: '#{file_path}'")
      nil
    rescue SystemCallError, IOError => error
      print_cli_error("Não foi possível ler o arquivo '#{file_path}': #{error.message}")
      nil
    end

    def run_pipeline(file_path, source, sections, color_enabled)
      source_lines = source.lines
      palette = Palette.new(enabled: color_enabled)
      renderer = Renderer.new(out: @out, palette: palette)

      lexer = Lexer.new(source)
      tokens = lexer.tokenize

      parser = Parser.new(tokens)
      ast = parser.parse

      can_run_semantic = lexer.valid? && parser.valid?
      if can_run_semantic
        semantic = SemanticAnalyzer.new(ast, lexer.symbols)
        semantic.analyze
      end

      renderer.render_header(file_path)
      renderer.render_tokens(tokens, lexer.errors, source_lines) if sections.include?(:tokens)
      renderer.render_symbol_table(semantic ? semantic.symbol_table : lexer.symbols) if sections.include?(:symbols)
      renderer.render_ast(ast, parser.errors, source_lines) if sections.include?(:ast)

      if sections.include?(:semantic)
        if can_run_semantic
          renderer.render_semantic(semantic.errors, source_lines)
        else
          renderer.render_semantic_skipped(!lexer.valid?, !parser.valid?)
        end
      end

      renderer.render_footer
      can_run_semantic && semantic.valid? ? 0 : 1
    end

    def print_usage
      @out.puts <<~USAGE
        Uso: ruby safira.rb <caminho/arquivo.c> [opções]

        Opções de visualização (por padrão exibe todas as 4 etapas):
          --tokens      Exibe apenas [1] Lista de Tokens
          --symbols     Exibe apenas [2] Tabela de Símbolos
          --ast         Exibe apenas [3] Árvore Sintática (AST)
          --semantic    Exibe apenas [4] Análise Semântica
          --no-color    Desativa cores ANSI na saída
          -h, --help    Exibe esta mensagem de ajuda
      USAGE
      0
    end

    def print_cli_error(message)
      @err.puts "✖ [ERRO] #{message}"
      @err.puts "Execute 'ruby safira.rb --help' para ver as instruções de uso."
      1
    end
  end
end

exit(SafiraCLI::Runner.run(ARGV)) if $PROGRAM_NAME == __FILE__
