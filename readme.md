# Quoted-Printable encoding for Nim


- https://en.wikipedia.org/wiki/Quoted-printable
- https://tools.ietf.org/html/rfc2045#page-19

```nim
import quotedPrintables

let org = "Iñtërnâtiônàlizætiøn☃💩"
let q = quoted(org)
echo q
#  I=C3=B1t=C3=ABrn=C3=A2ti=C3=B4n=C3=A0liz=C3=A6ti=C3=B8n=E2=98=83=F0=9F=92=
#  =A9
assert q.unQuoted == org
```