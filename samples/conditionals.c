/* Exemplo válido de estruturas condicionais: if, else if e else */
int main() {
    int nota = 7;
    int faltas = 3;
    float media = 6.5;
    char conceito = 'C';

    if (nota >= 9 && faltas < 5) {
        conceito = 'A';
    } else if (nota >= 7 || media > 7.0) {
        conceito = 'B';
    } else {
        conceito = 'C';
    }

    if (!(faltas > 10))
        media = media + 1;

    return 0;
}
