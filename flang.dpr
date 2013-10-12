program fLang;

{$IFDEF LINUX}
 {$mode objfpc}
{$ENDIF}

uses SysUtils;

type theVar=record
  Name:  string[32];
  Value: string[128];
end;

type theLabel=record
  Name: string[32];
  Addr: integer;
end;

type theFunc=record
  Name: string[32];
  Addr: integer;
end;

var
  returnAddress: array [1..255] of integer;
  code:          array of string[255];
  rezults:       array of string[255];
  vars:          array of TheVar;
  labels:        array of TheLabel;
  funcs:         array of TheFunc;
  fileName, lastRezult: string;
  i, returnIndex, cyclesCount: integer;
  isDebug: boolean=false;

procedure VoidVar;
var j: integer;
begin
  for j:=1 to length(vars)-1 do begin
    vars[j].Name:='void';
    vars[j].Value:='';
  end;
end;

function SetVar(v_name, v_value: string):string;
var j: integer;
begin
  if v_name[1]='_' then begin
    WriteLn(IntToStr(i)+': Unacceptable name "'+v_name+'"');
    SetVar:='~break';
    exit;
  end;
  for j:=1 to length(vars)-1 do begin
    if (vars[j].Name='void') or (vars[j].Name=v_name) then begin
      vars[j].Name:=v_name;
      vars[j].Value:=v_value;
      SetVar:=v_value;
      break;
    end;
  end;
end;

function GetVarIndex(v_name: string):integer;
var j: integer;
begin
  GetVarIndex:=0;
    for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    GetVarIndex:=j;
    break;
  end;
end;

function GetVarValue(v_name: string):string;
var j: integer;
begin
  for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    GetVarValue:=vars[j].Value;
    break;
  end;
end;

procedure SetLabel(l_name: string; l_address: integer);
var j: integer;
begin
  for j:=1 to length(labels)-1 do begin
    if (labels[j].Name='') or (labels[j].Name=l_name) then begin
      labels[j].Name:=l_name;
      labels[j].Addr:=l_address;
      break;
    end;
  end;
end;

function GetLabelAddr(l_name: string):integer;
var j: integer;
begin
  GetLabelAddr:=0;
  for j:=1 to length(labels)-1 do begin
    if labels[j].Name=l_name then begin
      GetLabelAddr:=labels[j].Addr;
      break;
    end;
  end;
end;

procedure SetFunc(f_name: string; f_address: integer);
var j: integer;
begin
  for j:=1 to length(funcs) do begin
    if (funcs[j].Name='') or (funcs[j].Name=f_name) then begin
      funcs[j].Name:=f_name;
      funcs[j].Addr:=f_address;
      break;
    end;
  end;
end;

function GetFuncAddr(f_name: string):integer;
var j: integer;
begin
  GetFuncAddr:=0;
  for j:=1 to length(funcs) do begin
    if funcs[j].Name=f_name then begin
      GetFuncAddr:=funcs[j].Addr;
      break;
    end;
  end;
end;

function TypeOf(InpStr: string):string;
var j: integer;
begin
  TypeOf:='int';
  if ((InpStr='full') or (InpStr='null') or (InpStr='')) then TypeOf:='bool';
  for j:=1 to length(InpStr) do begin
    if (InpStr[j] in [',', '.']) then begin
      TypeOf:='float';
      break;
    end;
    if not (InpStr[j] in ['0'..'9','-','+']) then begin
      TypeOf:='string';
      break;
    end;
  end;
end;

function StrHead(str: string; delimiter: string):string;
begin
  if pos(delimiter,str)<>0 then
    StrHead:=copy(str, 1, pos(delimiter, str)-length(delimiter))
  else
    StrHead:=str;
end;

function StrTail(str: string; delimiter: string):string;
begin
  if pos(delimiter,str)<>0 then
    StrTail:=copy(str, pos(delimiter, str)+length(delimiter), length(str)-1)
  else
    StrTail:='';
end;

procedure Preproc(codeEnd: integer);
var j: integer;
    cStrHead, cStrTail: string;
begin
  i:=0;
  j:=1;
  SetLength(vars, 1);
  SetLength(labels, 1);
  SetLength(funcs, 1);
  while(j<codeEnd) do begin
    cStrHead:=StrHead(code[j], ' ');
    cStrTail:=StrTail(code[j], ' ');
    if (cStrHead='#') or (cStrHead='//') then code[j]:='';
    if cStrHead='begin' then i:=j;
    if cStrHead='set' then SetLength(vars, Length(vars)+1);
    if cStrHead='label' then begin
      SetLength(labels, Length(labels)+1);
      SetLabel(cStrTail, j);
    end;
    if cStrHead='func' then begin
      SetLength(funcs, Length(funcs)+1);
      SetLength(vars, Length(vars)+2);
      SetFunc(cStrTail, j);
    end;
    inc(j);
  end;
  VoidVar;
end;

function ops(op: string):string;
var buf, temp: string;
begin
  buf:='';
  temp:=op;
  if isDebug then
    WriteLn('[Debug] (', i, '): Trying to ops `'+op+'`');
  if ((op[1]='"') and (op[length(op)]='"')) then
    temp:=copy(op, 2, length(op)-2) else
  if ((op[1]='[') and (op[length(op)]=']')) then begin
    buf:=copy(op, 2, length(op)-2);
    if buf='_last' then temp:=lastRezult else
    if buf='_ip'   then temp:=IntToStr(i) else
    if buf='_inp'  then repeat
      Write('> ');
      Readln(temp);
    until (temp<>'')
    else temp:=GetVarValue(buf);
  end;
  ops:=temp;
end;

function cclear(Expr: string):string;
var spFlag, qFlag: boolean;
    j: byte;
    buf: string;
begin
  qFlag:=false;
  spFlag:=true;
  buf:='';
  for j:=1 to length(Expr) do begin
    if Expr[j]='"' then qFlag:=not qFlag;
    if Expr[j]=' ' then begin
      if (spFlag=false) and (qFlag=false) then buf:=buf+Expr[j];
      spFlag:=true;
    end
    else spFlag:=false;
    if (spFlag=false) then buf:=buf+Expr[j];
    if (spFlag=true) and (qFlag=true) then buf:=buf+Expr[j];
  end;
  cclear:=buf;
end;

function OpenFile(fName: string; index: integer):integer;
var t: textfile;
    j: integer;
    buf: string;
begin
  if not (FileExists(fName)) then fName:=fName+'.src';
  if not (FileExists(fName)) then Exit;
  assign(t,fName);
  reset(t);
  j:=index;
  while not EOF(t) do begin
    SetLength(code,length(code)+1);
    Readln(t,buf);
    buf:=cclear(buf);
    if StrHead(buf,' ')='include' then j:=OpenFile(ops(StrTail(buf,' ')),j)
    else code[j]:=buf;
    inc(j);
  end;
  close(t);
  OpenFile:=j-1;
  SetLength(rezults,j);
  Preproc(j-1);
end;

procedure MakeJump(Address: string);
begin
  if isDebug then
    WriteLn('[Debug] (', i, '): Making jump to `'+ Address +'`');
  if TypeOf(Address)='int' then i:=StrToInt(Address);
  if TypeOf(Address)='string' then i:=GetLabelAddr(Address);
end;

function Execute(inpStr: string):string;
var fx, op1, op2, buf: string;
    j:integer;
begin
  Execute:='';

  while pos(', ',inpStr)<>0 do inpStr:=StringReplace(inpStr,', ',',',[rfreplaceall]);
  fx:=StrHead(inpStr,' ');
  buf:=StrTail(inpStr,' ');
  op1:=StrHead(buf,',');
  op2:=StrTail(buf,',');

  if GetFuncAddr(fx)<>0 then begin
    if (returnIndex>255) then begin
      WriteLn('[Error] Stack owerflow at line ', i);
      Execute:='~break';
      exit;
    end;
    if op1<>'' then SetVar(fx+'.x',ops(op1));
    if op2<>'' then SetVar(fx+'.y',ops(op2));
    returnAddress[returnIndex]:=i;
    inc(returnIndex);
    MakeJump(IntToStr(GetFuncAddr(fx)));
  end;

  if fx='return' then begin
    if op1<>'' then Execute:=ops(op1);
    dec(returnIndex);
    MakeJump(IntToStr(returnAddress[returnIndex]));
  end;

  if fx='unset' then begin
    SetVar(ops(op1), '');
    vars[GetVarIndex(ops(op1))].Name:='';
  end;

  if fx='eq' then begin
    if ops(op1)=ops(op2) then Execute:='0';
    if ops(op1)>ops(op2) then Execute:='1';
    if ops(op1)<ops(op2) then Execute:='-1';
  end;

  if fx='div' then begin
    if TypeOf(ops(op1))='float' then
      Execute:=FloatToStr(StrToFloat(ops(op1)) / StrToFloat(ops(op2)))
    else
      Execute:=IntToStr(StrToInt(ops(op1)) div StrToInt(ops(op2)));
  end;

  if fx='dbginfo' then begin
    WriteLn('[Debug] (', i, '): Generating debug info.');

    WriteLn('Variables');
    for j:=1 to Length(vars) do if vars[j].Name<>'' then Writeln(' Var['+
    IntToStr(j)+'] Name: `'+vars[j].name+'` Value: `'+vars[i].value+'`');

    WriteLn(' Functions');
    for j:=1 to Length(funcs) do if funcs[j].Name<>'' then Writeln('  Func['+
    IntToStr(j)+'] Name: `'+funcs[j].name+'` Address: `'+
    IntToStr(funcs[i].addr)+'`');

    WriteLn(' Labels');
    for j:=1 to Length(labels) do if labels[j].Name<>'' then Writeln('  Labels['+
    IntToStr(j)+'] Name: `'+labels[j].name+'` Address: `'+
    IntToStr(labels[i].addr)+'`');
    WriteLn('[Debug] (', i, '): Debug info generated. Press any key to countinue.');
    ReadLn;
  end;

  if fx='end'   then Execute:='~break';
  if fx='label' then Execute:=rezults[i-1];
  if fx='debug' then if ops(op1)='on' then isDebug:=true else isDebug:=false;
  if fx='nop'   then Sleep(StrToInt(ops(op1)));
  if fx='out'   then if op2='/n' then WriteLn(ops(op1)) else Write(ops(op1));

  if fx='set'   then Execute:=SetVar(ops(op1),ops(op2));

  if fx='add'   then Execute:=IntToStr(StrToInt(ops(op1)) + StrToInt(ops(op2)));
  if fx='sub'   then Execute:=IntToStr(StrToInt(ops(op1)) - StrToInt(ops(op2)));
  if fx='mul'   then Execute:=IntToStr(StrToInt(ops(op1)) * StrToInt(ops(op2)));
  if fx='mod'   then Execute:=IntToStr(StrToInt(ops(op1)) mod StrToInt(ops(op2)));

  if fx='conc'  then Execute:=ops(op1)+ops(op2);
  if fx='len'   then Execute:=IntToStr(length(ops(op1)));
  if fx='getc'  then Execute:=copy(ops(op1),StrToInt(ops(op2)),1);
  if fx='jmp'   then MakeJump(op1);

  if (fx='jez') and (StrToInt(ops(rezults[i-1]))=0)  then MakeJump(ops(op1));
  if (fx='jnz') and (StrToInt(ops(rezults[i-1]))<>0) then MakeJump(ops(op1));
  if (fx='jmz') and (StrToInt(ops(rezults[i-1]))>0)  then MakeJump(ops(op1));
  if (fx='jlz') and (StrToInt(ops(rezults[i-1]))<0)  then MakeJump(ops(op1));
end;

procedure StartExec(FileName: string);
begin
  SetLength(code, 1);
  SetLength(rezults, 1);
  WriteLn('[Info] Program started, '+IntToStr(OpenFile(FileName,1))+' strings loaded.');
  WriteLn;
  returnIndex:=1;
  cyclesCount:=0;
  repeat
    lastRezult:=rezults[i];
    inc(i);
    rezults[i]:=Execute(code[i]);
    if isDebug=true then
      WriteLn('[Debug] (', i, '): Expression `', code[i], '` returns `', rezults[i], '`');
    Inc(cyclesCount);
  until (rezults[i]='~break') or (i>=length(code));
  WriteLn;
  WriteLn('[Info] Program finished, '+IntToStr(cyclesCount)+' passes processed.');
end;

begin
  DecimalSeparator:='.';
  if FileExists(ParamStr(1)) then FileName:=ParamStr(1);
  WriteLn('fLang CLI v0.8.6c (04.10.2013), (C) Ramiil Hetzer');
  WriteLn('http://github.com/ramiil-kun/flang mailto:ramiil.kun@gmail.com');
  WriteLn('Syntax: '+ExtractFileName(ParamStr(0))+' [filename]');
  WriteLn;
  while (FileName='') do begin
    Write('File> ');
    Readln(FileName);
    if not ((FileExists(FileName)) or (FileExists(FileName+'.src'))) then FileName:='';
  end;
  StartExec(FileName);
  ReadLn;
end.
