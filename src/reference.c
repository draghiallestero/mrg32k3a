// Code taken from L'Ecuyer's paper

#include "reference.h"
#include <stdlib.h>

#define norm 2.328306549295728e-10
#define m1            4294967087.0
#define m2            4294944443.0
#define a12              1403580.0
#define a13n              810728.0
#define a21               527612.0
#define a23n             1370589.0

state* init()
{
  state* s = malloc(sizeof(state));
  s->s10 = 12345;
  s->s11 = 12345;
  s->s12 = 12345;
  s->s20 = 12345;
  s->s21 = 12345;
  s->s22 = 12345;
  return s;
}

unsigned draw(state*s)
{
  long k;
  double p1, p2;
  p1 = a12 * s->s11 - a13n * s->s10;
  k = p1 / m1; p1 -= k * m1; if (p1 < 0) p1 += m1;
  s->s10 = s->s11; s->s11 = s->s12; s->s12 = p1;

  p2 = a21 * s->s22 - a23n * s->s20;
  k = p2 / m2; p2 -= k * m2; if (p2 < 0) p2 += m2;
  s->s20 = s->s21; s->s21 = s->s22; s->s22 = p2;

  // The paper multiplies by norm here, however we want to return an integer
  if (p1 <= p2) return (p1 - p2 + m1);
  return (p1 - p2);
}
