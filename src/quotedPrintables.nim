## Quoted-Printable encoding for Nim
## https://tools.ietf.org/html/rfc2045#page-19

import strutils

const MAIL_SAFE* = Letters + Digits + {'\'', '(',')','+',',','-','.','/',':', ' ', '!'}
const cl = ['=', '\13', '\10']

proc initEncodeTable*(mailSave = MAIL_SAFE): array[256, string] =
  for ii in 0 ..< 256:
    let ch = char(ii)
    if ch in mailSave:
      result[ii] = $ch
    else:
      result[ii] = "=" & ch.ord().toHex(2)

when defined(release):
  {.push checks: off.}

const encodeTable = initEncodeTable()

proc quoted*(str: string, newlineAt = 76): string =
  ## encodes into Quoted Printables encoding
  # TODO:
  # - Avoid lookup table, do bit shifting
  # - result string is quite large, since we over allocate, copy to new string.
  result = newString( ((str.len div newlineAt) + 1) + str.len * 3 )
  var resPos = 0
  var lineChars = 0
  for ch in str:
    if lineChars + encodeTable[ch.int].len + 1 >= newlineAt: # ch + '='
      when defined(js) or defined(nimvm):
        result[resPos] = '='
        result[resPos + 1] = '\13'
        result[resPos + 2] = '\10'
      else:
        copyMem(addr result[resPos], unsafeAddr cl, sizeof(cl))
      resPos.inc 3
      lineChars = 0
    if encodeTable[ch.int].len == 3:
      when defined(js) or defined(nimvm):
        result[resPos] = encodeTable[ch.int][0]
        result[resPos + 1] = encodeTable[ch.int][1]
        result[resPos + 2] = encodeTable[ch.int][2]
      else:
        copyMem(addr result[resPos], unsafeAddr encodeTable[ch.int][0], 3)
      resPos.inc 3
    else:
      result[resPos] = encodeTable[ch.int][0]
      resPos.inc
    lineChars.inc encodeTable[ch.int].len
  result.setLen(resPos)


template parseHexDigit(ch: char): uint8 =
  var num: uint8
  if ch >= '0' and ch <= '9':
    num = cast[uint8](ch) - cast[uint8]('0')
  elif ch >= 'A' and ch <= 'F':
    num = cast[uint8](ch) - cast[uint8]('A') + 10.uint8
  else:
    err = true
    break
  num

proc unQuoted*(str: string): string =
  ## Decodes from quoted printables
  result = newString(str.len)
  var
    i: int = 0
    j: int = 0
    err = false
  while i < str.len:
    let ch = str[i]
    inc i
    if ch == '=':
      if i + 1 > str.len:
        err = true
        break
      let
        ch1 = str[i]
        ch2 = str[i + 1]
      # if ch1 == '\10': # enable support for unix line-ending
      #   i += 1
      if ch1 == '\13':
        if ch2 == '\10':
          i += 2
        else:
          err = true
          break
      else:
        let
          digit1 = ch1
          digit2 = ch2
          digitNum1 = parseHexDigit(digit1) shl 4
          digitNum2 = parseHexDigit(digit2)
        result[j] = (digitNum1 + digitNum2).char
        inc j
        i += 2
    else:
      result[j] = ch
      inc j

  if err:
    raise newException(ValueError, "Error at position: " & $i)

  result.setLen(j)

when defined(release):
  {.pop.}


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
      let tsts = @["Iñtërnâtiônàlizætiøn☃💩", "Здравствуйте", "中国", "Z͑ͫ̓ͪ̂ͫ̽͏̴̙̤̞͉͚̯̞̠͍A̴̵̜̰͔ͫ͗͢L̠ͨͧͩ͘G̴̻͈͍͔̹̑͗̎̅͛́Ǫ̵̹̻̝̳͂̌̌͘!͖̬̰̙̗̿̋ͥͥ̂ͣ̐́́͜͞'"]
      for tst in tsts:
        check tst == quoted(tst).unQuoted()

    # Fast unQuoted cannot do small hex
    # test "robust small hex":
    #   check "=3d".unQuoted() == "="

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

when true:
  import benchy
  let tst = "Iñtërnâtiônàlizætiøn☃💩".repeat(1000)
  timeIt("quoted"):
    let res = quoted(tst)
    keep res

  let qtst = tst.quoted()
  timeIt("unQuoted"):
    let res = unQuoted(qtst)
    keep res