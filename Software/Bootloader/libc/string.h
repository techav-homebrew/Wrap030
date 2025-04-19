

#ifndef _STRING_H_
#define _STRING_H_

typedef long size_t;

void *memcpy(void *__dst, const void *__src, size_t __n);
int memcmp(const void *__s1, const void *__s2, size_t __n);
void *memset(void *__b, int __c, size_t __len);
char *strchr(const char *__s, int __c);
int strcmp(const char *__s1, const char *__s2);

#endif