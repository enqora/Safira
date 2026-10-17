/*
 * Exemplo de código em C demonstrando o uso de laços de repetição:
 * 1. Laço 'while' (iteração baseada em condição prévia)
 * 2. Laço 'for'   (iteração com inicialização, condição e passo)
 */

int main() {
    /* Declaração de variáveis */
    int i = 0;
    int soma = 0;
    int limite = 10;
    int contador = 5;
    int fatorial = 1;

    /* ======================================================== */
    /* Exemplo 1: Laço 'while'                                  */
    /* Decrementa 'contador' até 0 e calcula o fatorial de 5     */
    /* ======================================================== */
    while (contador > 0) {
        fatorial = fatorial * contador;
        contador = contador - 1;
    }

    /* ======================================================== */
    /* Exemplo 2: Laço 'for'                                    */
    /* Soma todos os números inteiros de 1 até 'limite' (10)   */
    /* ======================================================== */
    for (i = 1; i <= limite; i = i + 1) {
        soma = soma + i;
    }

    /* Retorno da função principal */
    return 0;
}
