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

      prefix = styles.map { |s| CODES[s] }.compact.join
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
      invalid_operation: 'Operação inválida'
    }.freeze

    def initialize(out: $stdout, palette: Palette.new)
      @out = out
      @p = palette
    end

    def render_header(file_path)
      @out.puts @p.colorize(BANNER_LINE, :blue, :bold)
      @out.puts @p.colorize('  SAFIRA COMPILER — Análise de Código C', :bold)
      @out.puts "  Arquivo: #{@p.colorize(file_path, :cyan)}"
      @out.puts @p.colorize(BANNER_LINE, :blue, :bold)
    end

    def render_footer
      @out.puts @p.colorize(BANNER_LINE, :blue, :bold)
    end

    def render_tokens(tokens, lexical_errors, source_lines)
      @out.puts
      @out.puts @p.colorize('[1] ANÁLISE LÉXICA: LISTA DE TOKENS', :yellow, :bold)
      @out.puts @p.colorize(SECTION_LINE, :dim)

      if tokens.empty? && lexical_errors.empty?
        @out.puts ' (Nenhum token encontrado)'
      else
        tokens.each do |token|
          @out.puts " #{format_token_line(token)}"
        end
      end

      return if lexical_errors.empty?

      @out.puts
      lexical_errors.each do |err|
        length = [err.char.to_s.length, 1].max
        render_diagnostic(
          tag: 'ERRO LÉXICO',
          title: 'Token inválido',
          line: err.line,
          column: err.column,
          length: length,
          message: err.message,
          source_lines: source_lines
        )
      end
    end

    def render_symbol_table(symbols)
      @out.puts
      @out.puts @p.colorize('[2] TABELA DE SÍMBOLOS', :yellow, :bold)
      @out.puts @p.colorize(SECTION_LINE, :dim)

      headers = ['Identificador', 'Tipo', 'Linha', 'Ordem Inserção']
      rows = symbols.map do |entry|
        [
          entry.name.to_s,
          (entry.type || 'indefinido').to_s,
          entry.line.to_s,
          entry.order.to_s
        ]
      end

      min_widths = [13, 7, 6, 14]
      widths = headers.each_index.map do |idx|
        content_max = ([headers[idx]] + rows.map { |r| r[idx] }).map(&:length).max
        [content_max, min_widths[idx]].max
      end

      border = " +-#{widths.map { |w| '-' * w }.join('-+-')}-+"
      header_line = " | #{headers.each_with_index.map { |h, i| h.ljust(widths[i]) }.join(' | ')} |"

      @out.puts border
      @out.puts header_line
      @out.puts border

      if rows.empty?
        empty_width = widths.sum + (3 * (widths.size - 1))
        @out.puts " | #{'(Nenhum identificador registrado)'.ljust(empty_width)} |"
      else
        rows.each do |row|
          formatted_cells = row.each_with_index.map { |cell, i| cell.ljust(widths[i]) }
          @out.puts " | #{formatted_cells.join(' | ')} |"
        end
      end

      @out.puts border
    end

    def render_ast(ast, parse_errors, source_lines)
      @out.puts
      @out.puts @p.colorize('[3] ANÁLISE SINTÁTICA: ÁRVORE SINTÁTICA (AST)', :yellow, :bold)
      @out.puts @p.colorize(SECTION_LINE, :dim)

      declarations = Array(ast&.declarations)
      if declarations.empty? && parse_errors.empty?
        @out.puts ' (Árvore vazia)'
      else
        declarations.each_with_index do |node, idx|
          label, children = ast_to_tree(node)
          @out.puts " #{@p.colorize(label, :yellow, :bold)}"
          render_tree_children(children, ' ')
          @out.puts if idx < declarations.size - 1
        end
      end

      return if parse_errors.empty?

      @out.puts if declarations.any?
      parse_errors.each do |err|
        length = [err.lexeme.to_s.length, 1].max
        render_diagnostic(
          tag: 'ERRO SINTÁTICO',
          title: 'Falha gramatical',
          line: err.line,
          column: err.column,
          length: length,
          message: err.message,
          source_lines: source_lines
        )
      end
    end

    def render_semantic(semantic_errors, source_lines, has_prior_errors: false)
      @out.puts
      @out.puts @p.colorize('[4] ANÁLISE SEMÂNTICA', :yellow, :bold)
      @out.puts @p.colorize(SECTION_LINE, :dim)

      if semantic_errors.empty?
        if has_prior_errors
          @out.puts @p.colorize(
            ' ⚠ Análise semântica concluída sem novos erros (corrija os erros léxicos/sintáticos acima).',
            :yellow
          )
        else
          @out.puts @p.colorize(' ✔ Nenhuma inconsistência semântica encontrada.', :green, :bold)
        end
        return
      end

      semantic_errors.each_with_index do |err, idx|
        title = SEMANTIC_TITLES[err.kind] || 'Inconsistência semântica'
        render_diagnostic(
          tag: 'ERRO SEMÂNTICO',
          title: title,
          line: err.line,
          column: err.column,
          length: [err.length.to_i, 1].max,
          message: err.message,
          source_lines: source_lines
        )
        @out.puts if idx < semantic_errors.size - 1
      end
    end

    def render_diagnostic(tag:, title:, line:, column:, length:, message:, source_lines:)
      header = " ✖ [#{tag}] #{title} na linha #{line}:"
      @out.puts @p.colorize(header, :red, :bold)

      code_line = source_lines[line - 1].to_s.chomp
      gutter_width = [line.to_s.length + 5, 6].max
      line_label = line.to_s.rjust(gutter_width)
      blank_gutter = ' ' * gutter_width

      @out.puts "#{line_label} | #{code_line}"

      offset = [column.to_i - 1, 0].max
      carets = '^' * [length.to_i, 1].max
      pointer = @p.colorize("#{carets} #{message}", :red)
      @out.puts "#{blank_gutter} | #{' ' * offset}#{pointer}"
    end

    private

    def format_token_line(token)
      format(
        '[Linha %<line>2d, Col %<col>2d]  TIPO: %<type>-16s | LEXEMA: \'%<lexeme>s\'',
        line: token.line,
        col: token.column,
        type: token.type.to_s,
        lexeme: token.lexeme
      )
    end

    def render_tree_children(children, prefix)
      children.each_with_index do |(label, subchildren), idx|
        last = (idx == children.size - 1)
        connector = last ? '└── ' : '├── '
        @out.puts "#{prefix}#{connector}#{label}"
        next_prefix = prefix + (last ? '    ' : '│   ')
        render_tree_children(subchildren, next_prefix)
      end
    end

    def ast_to_tree(node)
      case node
      in VarDeclNode[type_token:, name_token:, expression: nil]
        ['Declaracao', [
          ["TIPO_DADO (#{type_token.lexeme})", []],
          ["ID (#{name_token.lexeme})", []]
        ]]
      in VarDeclNode[type_token:, name_token:, expression:]
        ['Declaracao', [
          ["TIPO_DADO (#{type_token.lexeme})", []],
          ["ID (#{name_token.lexeme})", []],
          ['OP_ATRIB (=)', []],
          ast_to_tree(expression)
        ]]
      in AssignNode[target:, expression:]
        ['Atribuicao', [
          ["ID (#{target.lexeme})", []],
          ['OP_ATRIB (=)', []],
          ast_to_tree(expression)
        ]]
      in BinaryOpNode[left:, operator_token:, right:]
        ["Expressao (#{operator_token.lexeme})", [
          ast_to_tree(left),
          ast_to_tree(right)
        ]]
      in IdentifierNode[token:]
        ["ID (#{token.lexeme})", []]
      in NumberNode[token:]
        ["NUM (#{token.lexeme})", []]
      in StringNode[token:]
        ["STR (#{token.lexeme})", []]
      in CharNode[token:]
        ["CHAR (#{token.lexeme})", []]
      else
        [node.class.name.to_s, []]
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

    ALL_SECTIONS = %i[tokens symbols ast semantic].freeze

    def self.run(argv, out: $stdout, err: $stderr)
      new(argv, out: out, err: err).execute
    end

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def execute
      options = parse_options
      return print_usage(0) if options[:help]
      return print_cli_error(options[:error]) if options[:error]

      source = read_source_file(options[:file])
      return 1 if source.nil?

      run_pipeline(options[:file], source, options[:sections], options[:color])
    rescue StandardError => e
      print_cli_error("Falha inesperada ao processar o arquivo: #{e.message}")
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
      unless File.exist?(file_path)
        print_cli_error("Arquivo não encontrado: '#{file_path}'")
        return nil
      end

      if File.directory?(file_path)
        print_cli_error("O caminho informado é um diretório, não um arquivo: '#{file_path}'")
        return nil
      end

      File.read(file_path, encoding: 'UTF-8')
    rescue SystemCallError, IOError => e
      print_cli_error("Não foi possível ler o arquivo '#{file_path}': #{e.message}")
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

      semantic = SemanticAnalyzer.new(ast, lexer.symbols)
      semantic.analyze

      renderer.render_header(file_path)
      renderer.render_tokens(tokens, lexer.errors, source_lines) if sections.include?(:tokens)
      renderer.render_symbol_table(semantic.symbol_table) if sections.include?(:symbols)
      renderer.render_ast(ast, parser.errors, source_lines) if sections.include?(:ast)

      if sections.include?(:semantic)
        has_prior_errors = !lexer.valid? || !parser.valid?
        renderer.render_semantic(semantic.errors, source_lines, has_prior_errors: has_prior_errors)
      end

      renderer.render_footer

      lexer.valid? && parser.valid? && semantic.valid? ? 0 : 1
    end

    def print_usage(exit_code)
      @out.puts <<~USAGE
        Uso: ruby compiler.rb <caminho/arquivo.c> [opções]

        Opções de visualização (por padrão exibe todas as 4 etapas):
          --tokens      Exibe apenas [1] Lista de Tokens
          --symbols     Exibe apenas [2] Tabela de Símbolos
          --ast         Exibe apenas [3] Árvore Sintática (AST)
          --semantic    Exibe apenas [4] Análise Semântica
          --no-color    Desativa cores ANSI na saída
          -h, --help    Exibe esta mensagem de ajuda
      USAGE
      exit_code
    end

    def print_cli_error(message)
      @err.puts "✖ [ERRO] #{message}"
      @err.puts "Execute 'ruby compiler.rb --help' para ver as instruções de uso."
      1
    end
  end
end

exit(SafiraCLI::Runner.run(ARGV)) if $PROGRAM_NAME == __FILE__
