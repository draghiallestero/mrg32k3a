#include <stdio.h>

typedef struct
{
 double s10;
 double s11;
 double s12;
 double s20;
 double s21;
 double s22;
} state;

state* init();

unsigned draw(state* p_state);