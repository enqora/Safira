#include <stdio.h>

/* Demonstração de uso do comando printf suportado pelo Safira */
int main() {
    int idade = 21;
    float media = 8.75;
    char conceito = 'A';

    printf("Sistema Safira\n");
    printf("Idade: %d | Media: %.2f | Conceito: %c\n", idade, media, conceito);
    printf("Progresso: 100%%\n");

    for (int i = 1; i <= 3; i++) {
        printf("Iteracao %d: dobro = %d\n", i, i * 2);
    }

    return 0;
}
