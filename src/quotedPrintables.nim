## Quoted-Printable encoding for Nim
## https://tools.ietf.org/html/rfc2045#page-19

import strutils, parseutils

const MAIL_SAFE* = Letters + Digits + {'\'', '(',')','+',',','-','.','/',':', ' ', '!'}

template addCL() =
  result.add "=\c\l"
  lineChars = 0

proc initEncodeTable*(mailSave = MAIL_SAFE): array[256, string] =
  for ii in 0 ..< 256:
    let ch = char(ii)
    if ch in mailSave:
      result[ii] = $ch
    else:
      result[ii] = "=" & ch.ord().toHex(2)

const encodeTable = initEncodeTable()

proc quoted*(str: string, newlineAt = 76): string =
  ## encodes into Quoted Printables encoding
  result = newStringOfCap(str.len)
  var lineChars = 0
  for ch in str:
    if lineChars + encodeTable[ch.int].len + 1 >= newlineAt: # ch + '='
      addCl
    result.add(encodeTable[ch.int])
    lineChars.inc encodeTable[ch.int].len

proc unQuoted*(str: string): string =
  ## Decodes from quoted printables
  result = newStringOfCap(str.len)
  var
    pos: int = 0
    ch: char
  while pos < str.len:
    ch = str[pos]
    if ch == '=':
      pos.inc # skip =
      var skipped = str.skipWhile({'\l', '\c'}, pos)
      if skipped > 2:
        raise newException(ValueError, "Could not Encode, error at: " & $pos)
      if skipped == 0:
        var hexNum: uint8
        skipped = parseHex[uint8](str, hexNum, pos, 2)
        if skipped != 2:
          raise newException(ValueError, "could not parse hex at:" & $pos)
        else:
          result.add hexNum.chr
      pos.inc skipped
    else:
      result.add ch
      pos.inc

when isMainModule:
  import unittest

  suite "quotedPrintables":

    test "defaults":
      check quoted("=") == "=3D"
      check quoted("a") == "a"
      check quoted("ä") == "=C3=A4"
      check quoted("ää") == "=C3=A4=C3=A4"
      check quoted("\c\l") == "=0D=0A"

    test "quoted_unQuoted":
      let tsts = @["Iñtërnâtiônàlizætiøn☃💩", "Здравствуйте", "中国"]
      for tst in tsts:
        check tst == quoted(tst).unQuoted()

    test "robust small hex":
      check "=3d".unQuoted() == "="

    test "max chars per line":
      let tst = ($AllChars).repeat(10)
      block:
        let qtst = quoted(tst, newlineAt = 76)
        for line in qtst.splitLines():
          assert line.len <= 76
      block:
        let qtst = quoted(tst, newlineAt = 5)
        for line in qtst.splitLines():
          assert line.len <= 5