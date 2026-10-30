{$A+,S45,P-,R-,T-}
program DX_Loader;

{MIDI exclusive data empfangen, senden, speichern, DX-7 Sounds ausdrucken }

{Ia:\dx7\MIDI.INC}
(*---------------- midi.inc -----------------*)
Const
    resX=640; resY=400;
    Bell=#7; CE=#27; CRET=#13; CL=#8; CTH=#8; CTU=#21;
    marker=#8; DirMarker=#7;
    IOBUFLen=4120;
    SetHiBank=8;
    MaxDir=192;
    EOX=$F7;

Type
{     screen_L = packed array[0..7999] of Long_integer;
{     palette = packed array[0..15] of Integer;
{     screen_type = packed record
{         res:integer;
{         pal:palette;
{         pic:screen_L;
{     end;
}
     b_ptr = ^byte; c_ptr = ^char; i_ptr = ^integer; l_ptr = ^long_integer;
     mxcbuftype = packed array[0..IObuflen] of byte; { !! mem !! }
     Transfertype = (read_, write_);
     formattype = (HMP,BEAM_TEAM,STEINBERG,XALYZER);
     functype = (none,soundnames,filenames,manager);
     ovrname  = (Onone,Ofiles,Oinit1,Oeditsound,Oprintsounddata,Obnkmanager);
     dosname  = packed array[0..32] of char;
     CCAtype  = packed array[0..14] of char;
     string255  = string[255];
     string128  = string[128];
     intostring = string[130];
     string100  = string[100];
     string32   = string[32];
     string16   = string[16];
     filename   = string[14];
     string2    = string[2];

     SXCtype = packed array[0..5]  of char;
     DX_NAME = packed array[1..10] of char;
     dx_op = record
           EG : array[1..8] of integer;
              {EgR1, EgR2, EgR3, EgR4,
              {EgL1, EgL2, EgL3, EgL4,}
          {Breakpoint, DEpthL, DepthR, CurveL, CurveR,
          {KeyRateSc, AM_Sens, Velocity, OutLevel,
          {OscMode, FreCo, FreFine, Detune  :  integer;}
           Detune,FreFine,FreCo,OscMode,OutLevel,Velocity,AM_Sens,
           KeyRateSc,CurveR,CurveL,DepthR,DepthL,BreakPoint : integer;
     end;
     dx_sound = record
           oper : array[1..6] of dx_op;   { 6 * 21 bytes }
           PEG  : array[1..8] of integer;
               {PegR1, PegR2, PegR3, PegR4,
               {PegL1, PegL2, PegL3, PegL4,}
          {Algo, Feedb, OscSync,
          {LFO_Speed, LFO_Delay, LFO_PMD, LFO_AMD,
          {LFO_Sync, LFO_Wave,
          {P_Mod, Transpose : integer;}
           Transpose,P_mod,LFO_Wave,LFO_Sync,LFO_AMD,LFO_PMD,
           LFO_Delay,LFO_Speed,OscSync,Feedb,Algo : integer;
           VoiceName : array[1..10] of char;    { ?? packed ?? }
     end;
     BigBuffer = packed array[0..IOBUFlen] of byte;
     sector  = packed array[0..127]  of byte;
     secs = packed record case integer of
           1: (sec: sector);
           2: (a: packed ARRAY[0..117]of byte; VoiceName:DX_Name)
       end;
     dx_bank = packed ARRAY[1..32] of secs;
     bankbuftype = packed record case integer of
           1: ( Len : integer;
                SXC : sxctype;
                Bnk : DX_Bank;
                chsum: byte;
                eox: byte;
                dummy:integer );
           2: ( l:integer; c:mxcbuftype) ;
           3: ( b:bigbuffer);
       end;
     soundxptype = bigbuffer; {packed array[0..167] of byte   !!! mem !!!}
     soundbuftype = packed record case integer of
           1: (xx:byte; B: soundxptype);    { to hold 1 DX_sound }
           1: (yq:byte; b1:packed array[0..170] of byte);
           2: (yy:byte; Len: INTEGER; SXC:sxctype; );
           3: (S:string[167]);
           4: (zz:byte; C:packed array[0..167] of char);
       end;
     usoundbuftype = record case integer of
           2: ( Len: INTEGER; SXC:array[0..6] of byte; PAR:dx_sound);
           3: ( U: array[0..170] of byte);
       end;
     packedsound = packed record case INTEGER of
           1: (xx:byte; b: sector);
           2: (yy:byte; a: packed array[0..117] of byte; VoiceName: dx_name);
           3: (s: intostring);
       end;
     blockptr = ^bankbuftype;

Var
{   screenmem: screen_type;     !!! mem 32k !!! }
    BUFPTR:   ^bankbuftype; (*??*)
    Buffers:  ARRAY[1..SetHiBank] of blockptr;
    BufName:  ARRAY[1..SetHiBank] of filename;
    EmptyBuf: filename;
    SOUNDBUF: soundbuftype;
    USoundBuf: usoundbuftype;
    CDATA :   packedsound;
    CNAME :   string[10];
    Drive, A,BUFLEN,Number,N   : integer;
    CYAMAHA, CSOUND, CBANK   : string[4];
    CNOTES,CWAVES: string[40]; CURVES,COFFON: string[8];
    DataFormat : formattype;
    LeftWindow,FPRINT,FSB,Dummy, L_acc: Boolean;
    LastFunction : functype;
    ODrive   : string2;   { Overlay drv. }
    OvrFName : filename;{ O-Filename }
    OvrActive : ovrname;{ Ovr in memory }
    HiBank, CurrentBank, TestBank, FreBnk, Somany, FilOfs, Lastcursor : INTEGER;
    CHiBank:char;
    CF, CF1: string32;
    WrkDRV : string2;
    OldPath: dosname;
    FilesFound: ARRAY[1..MaxDir] of filename;
    Spaces,CC: string[255];
    C:  char;
    Ldummy: boolean; Ndummy: integer; Cdummy: char;
    LST : text;
{--------------------------- MIDI -------------------------}
type
     midicontrol=record case integer of
     1:(adr: long_integer;
        max,min,readpos,writepos,len : integer);
     2:(b:packed array[0..13] of byte);
     end;
     mrectype= ^midicontrol;
     systype=packed record case integer of
     1:(joyrt,  clockrt,  mousert, kbstat, miderr, kyberr,
        midin : long_integer);
     2:(b:packed array[0..63] of byte);
     end;
     sysptrtype=^systype;
var
     sysmidi,applmidi : midicontrol;
     sysmidinptr:long_integer;
     midirecptr: mrectype;
     sysMintptr,applMintptr:long_integer;
     iointptrs:sysptrtype;
{$P-,R-}
function iorec(auxconmidi:integer) : mrectype; xbios(14);

function getvec : sysptrtype; xbios(34);
{$P=,R=}
{----------------------- GEM SHIT -----------------------------------}
const
    AC_Open=40; AC_Close=41;
    WM_closed=22;
    G_all=$FEF;
    G_info=$010;
    E_Keyboard=1;
    E_Message=16;
type
    Window_Title=string[8];
    message_buffer=array[0..15] of integer;
var
    ap_id,menu_id,event,W_handle,d:integer;
    msg:message_buffer;
    W_title:window_title;
    AccName:string16;

function Init_gem : integer;external;
procedure exit_gem;external;
procedure paint_style(n:integer);external;
procedure paint_color(n:integer);external;
procedure paint_rect(x,y,w,h:integer);external;
function Get_Event( emask,bmask,bstate,n_clix:integer; tix:long_integer;
            m1_flag:boolean; m1x,m1y,m1w,m1h:integer;
            m2_flag:boolean; m2x,m2y,m2w,m2h:integer;
            Var message:message_buffer;
            Var key,brtn,bclick,mx,my,kstate:integer ):integer;external;
function Menu_Register(id:integer; var name:string16 ):integer; external;
{function New_Window(wtype:integer;var title:Window_title;x,y,w,hmax:integer):integer;
{  external;
}
procedure Open_Window(handle,x,y,w,h:integer); external;
procedure Close_Window(handle:integer);external;
procedure Delete_Window(handle:integer);external;
function front_window: integer; external;
procedure wind_get(handle,req:integer;var v1,v2,v3,v4:integer);external;
{----------------------- END GEM ------------------------------------}

function fcreate(var name:dosname; attr:integer):integer;gemdos($3C);
function fopen(var name:dosname; attr:integer):integer;gemdos($3D);
function fclose(handle:integer):integer;gemdos($3E);
function fread(handle:integer;size,buf:long_integer):long_integer;gemdos($3F);
function fwrite(handle:integer;size,buf:long_integer):long_integer;gemdos($40);
function fseek(offset:long_integer;handle,mode:integer):long_integer;gemdos($42);
function getdrv:integer;gemdos(25);
function setdrv(drv:integer):integer;gemdos(14);
procedure getpath(var pabuf:dosname; drv:integer);gemdos(71);
                                     {0=default }
function  setpath(var pabuf:dosName):integer;gemdos(59);

{procedure move_l(source,dest,count:long_integer); external;
{procedure move_w(source,dest,count:long_integer); external;
{procedure move_b(source,dest,count:long_integer); external;}

{procedure get_screen(var buf:screen_type);external;
{procedure put_screen(var buf:screen_type);external;}

procedure grafchar(c:char);external;
procedure end_of_line; external;
 procedure clreol; begin end_of_line end;
procedure clear_home; external;
 procedure clrscr; begin clear_home end;
procedure gotoxy(x,y:integer); external;
procedure end_of_screen; external;
procedure clear_line; external;
procedure inv_on; external;
procedure inv_off; external;
procedure Cur_on;external;
procedure Cur_off;external;
procedure save_cursor; external;
procedure restore_cursor; external;
function gemdos7:long_integer; (* gemdos7 *)
  gemdos(7);
function keypressed : boolean;
   begin keypressed:=keypress end;
procedure clearKBD; var n:integer;
 begin while keypressed do n := gemdos7 & $FF; end;

procedure delay(tt:real); {--sec--}
var n:long_integer;
begin
  n:=long_round(tt*96000);
  while n>0 do n:=pred(n);
end;

{function ptr_byte(addr:long_integer): B_PTR; external;
{function ptr_char(addr:long_integer): C_PTR; external;
{function ptr_integer(addr:long_integer): I_PTR; external;}

function adr_byte(var Bvar:bigbuffer):long_integer; external;
{function adr_char(var Cvar:char):long_integer; external;
{function adr_integer(var Ivar:integer):long_integer; external;}

function iifN(LL:boolean; p1,p2:integer):integer;
begin if LL then iifN:=p1 else iifN:=p2 end;

function revint(n:integer):integer;
begin
  revint:=(shr(n,8)+shl(n,8)) & $FFFF;
end;

procedure writehex(l:integer);
begin
(*  CC:='';
  repeat
    c1:= digits[succ(l&$0000000F)];
    cc:=concat(c1,cc);
    l:=shr(l,4);
  until l=0;
  write(cc); //
  write (digits[succ(shr(l,4)&$F)], digits[succ(l&$F)],' '); *)
  write(l:2:h, ' ');
end;

procedure frame; forward;

procedure dumpbank(var buf:bigbuffer; range:integer);
label 99;
var n,n1:integer; ch:char;
begin 
{with buf do begin}
n1:=0; clrscr;
repeat
  if keypressed then begin 
     read(ch); if ch=CE then goto 99;
  end;
  for n:=0 to 15 do begin 
    writehex(buf[n+n1]);
  end;
  write('  ');
  for n:=0 to 15 do begin
     ch:=chr(buf[n+n1]); if (ch>=' ') and (ch<'~') then write(ch) else write('.'); 
     if(n+n1>=range) then goto 99;
  end;
  writeln; n1:=n1+16;
until false;
99: read(ch); frame;
{end; }

end;

procedure VAL(CC:filename; var n,errflg:integer);
label 99;
var nn:integer;
begin
  IO_check(false);
  readv(CC,n);  errflg:=IO_result;
  if errflg<>0 then begin n:=0; end;
  IO_check(true);
99:
end;

procedure GrossC(var C:char);
begin
  if (c>='a') and (c<='z') then c:= chr(ord(c)&$DF);
end;

procedure Gross(var cc:filename);
var n:integer; c:char;
begin 
  for n:=1 to length(CC) do begin
    C:=CC[N]; GrossC(C); CC[N]:=C;
  end;
end;

procedure StrToDos(s:string32; var cc:dosname);
var n:integer;
begin 
  for n:=1 to length(s) do cc[pred(n)]:=s[n];
  for n:=length(s) to 31 do cc[n]:=#0;
end;

procedure DosToCC(cc:dosname; var s:string32);
var n:integer;
label 99;
begin 
  s:=copy(spaces,1,32);
  for n:=0 to 31 do begin
    if cc[n]=#0 then goto 99;
    s[succ(n)]:=cc[n];
  end;
99: { l„nge =14 fix! oder s[0]:=pred(n); }
end;

procedure dostostr(CC:dosname; var s:filename);
var CF:string32;
begin
  dostocc(CC,CF); s:=copy(CF,1,14)
end;

procedure writeC(CC:dosname);
var n:integer;
begin
  n:=1;
  while CC[N]<>#0 do begin 
    write(CC[N]);N:=succ(N);
  end;
end;

{$P-,R-}
PROCEDURE MIDIN(var datp:blockptr; var allowlen:integer);
label 1,99;
var n:integer;
begin {---------midin-------}
IOintPtrs^.midin := SysMintPtr;
1:
for n:=1 to IOBuflen do  datp^.b[N]:=0;
{  if datp^.b[n]=EOX then begin datp^.b[N]:=0;goto 1 end;}
with midirecptr^ do begin
  adr := adr_byte(datp^.b) + 2; readpos:=0; writepos:=0; len:=allowLen-3;
  if odd(adr) then adr:=adr+1;
  max:=IOBUFlen-3; min:=1;
  repeat
   for n:=128 to IOBuflen do if datp^.b[n]=EOX then goto 99;
  until keypressed or (readpos>=pred(len));
end;
99:
allowlen:=midirecptr^.readpos;
midirecptr^ := Applmidi; IOintPtrs^.midin:=ApplMintPtr;
clearKBD; {delay(0.5);}

end; {midin}
{$P=,R=}

procedure midiws(MLEN:integer; var CC:mxcbuftype);
  xbios(12);
PROCEDURE MIDOUT(var data:mxcbuftype; len:integer);
  begin midiws(len,data) end;

FUNCTION CHSUM(var data:mxcbuftype) :boolean;
label 99;
var t,s:integer; x:byte;
begin
  chsum:=false ;
  t:=0;
  while (data[t]<>$F0) and (t<20) do t:=succ(t);
   { auf $43 (YAMAHA) testen:}
  if (data[t+1]<>$43) then goto 99;
  s:= shl(data[t+4],7) + data[t+5];
  if data[t+s+1]<>EOX then data[4106]:=EOX; {goto 99; {L„nge muž stimmen!}
  s:=0;t:=t+6;
  x:=data[t];
  while (x<>EOX) and (t<IOBuflen) do begin
    s:=s+x; t:=succ(t); x:=data[t];
  end;
  chsum:= (s & $7F)<>0;
  t:=pred(t); s:=s-data[t];
  data[t]:= 128 - (s & $7F);
99: end;

function CONIN:char;
var l:long_integer;
begin
  l:=gemdos7; conin:=chr(l&$FF);
  l:=shr(l,16);
{ if ( l in [75,77,72,80,115,116,71,82] ) then }
  case l of
   75: conin:=#19; 115: conin:=#1;
   77: conin:=#4;  116: conin:=#6;
   72: conin:=#5;   80: conin:=#24;
   82: conin:=#14;  71: conin:=#12;
  end;
end;

procedure BOX(x1,y1,x2,y2:integer);
procedure Pbox;
begin
  line(x1,y1,x2,y1,1,1,1,1,-1,1);
  line(x2,y1,x2,y2,1,1,1,1,-1,1);
  line(x2,y2,x1,y2,1,1,1,1,-1,1);
  line(x1,y2,x1,y1,1,1,1,1,-1,1);
end;
begin {box}
  gotoxy(succ(x1),succ(y1));
  x1 := 5 + (x1-1) * (resX div 80); x2 := 3 + (x2-1) * (resX div 80);
  y1 := 8 + (y1  ) * (resY div 24); y2 := 6 + (y2  ) * (resY div 24);
  Pbox;
  x1:=pred(x1); x2:=succ(x2); y1:=pred(y1); y2:=succ(y2);
  Pbox;
  x1:=pred(x1); x2:=succ(x2); y1:=pred(y1); y2:=succ(y2);
  Pbox;
end;

PROCEDURE QuitToSystem ;
var i:integer;
    x,y,w,h:array[0..4] of integer;
begin 
  Cur_off; clrscr; 
  ndummy:=setdrv(drive); ndummy:=setpath(OldPath);
  {$P-,R-}
  midirecptr^ := Applmidi; IOintPtrs^.midin:=ApplMintPtr;
  {$P=,R=}
{  hide_mouse;  put_screen(screenmem); show_mouse }
{  Close_Window(W_handle);
  delete_window(w_handle);}
  if L_acc then begin
    n:=front_window; hide_mouse; i:=n;
    if n>0 then begin
    {for i:=1 to n do    } wind_get(i,5,x[i],y[i],w[i],h[i]);
    {for i:=n downto 1 do} close_window(i);
    {for i:=1 to n do    } open_window(i,x[i],y[i],w[i],h[i]);
    end;
    show_mouse;
  end else begin
    if (ap_id>0) then exit_gem;
    halt;
  end;
end;

PROCEDURE GetCapKey;
begin
  C:=conin; grossC(C); 
  if (ord(C)>32) then write(C,CL);
  if C='#' then begin gotoxy(65,24); write(memavail); end;
end;

PROCEDURE Frame;
begin
  clrscr; GOTOXY(29,1); writeln('M I D I - L O A D E R           H.M.P.-Soft');
  box(1,0,80,2); box(1,2,41,19); box(41,2,80,19); 
end;

PROCEDURE clearbox;
var n,xoffs:integer;
begin
  xoffs := iifN(LeftWindow, 1, 41);
  paint_style(0);paint_color(0);
  paint_rect(xoffs*8, 42, (38)*8, 266);
end;

PROCEDURE clear24;
begin GOTOXY(0,24); clreol; end;

procedure fillstr(var CC:string100; count:integer; a:char);
var  n:integer;
begin
  if (count>0) and (count<100) then begin
   for n:=1 to count do CC[n]:=a;
   CC[0]:=chr(count);
  end;
end;

PROCEDURE clears(a,b:INTEGER);
var n:INTEGER;
begin for n:= a to b do begin gotoxy(0,n); clreol; end; end;

PROCEDURE NoBlanks(Var CF:filename);
begin repeat
   A:=pos(' ',CF); if A<>0 then delete(CF,A,1);
until A=0;
end;

FUNCTION OvrHere(OvrNew:ovrname) :boolean;
(*var f:text; OK:boolean;*)
BEGIN
(*  Ok:= (ovrnew=ovractive);
  if not Ok then begin
  {$I-} assign(f,ODrive+OvrFName); reset(f);  {$I+}
     Ok:= (ioresult=0); close(f);
     if Ok then begin
        OvrActive:=OvrNew;
     end else begin
        clear24; WRITE(' ? Programmdiskette ', Bell);
     end;
  end;
  OvrHere:=Ok; *)
  ovrhere:=true;
END;

PROCEDURE GetName;  { CC=helptext, CF=return }
var l:integer;
begin
clear24; write(CC, '---------------'); l:=length(CC);
GOTOXY(1,23); clreol; write(' ':l-1, '<', CF, '>':13-length(CF)); CC:=CF;
GOTOXY(succ(l),23); repeat until keypressed; clreol; write(CL,'<              >');
GOTOXY(succ(l),23); readln(CF); if CF='' then begin CF:=CC; write(CC); end;
end;

procedure CatchNumber(max:integer);
begin if Number<=0 then Number:=1; if Number>max then Number:=max end;

PROCEDURE curp(n:integer);
  var xoffs:INTEGER;
  begin
    if LeftWindow then 
       xoffs:=3
    else begin
       xoffs:=43;
       n:=n & 63;
    end;
    GOTOXY(xoffs+20*(shr(pred(N),4)), 3+(pred(N) & $000F));
  end;

PROCEDURE putmarke;
begin curp(Lastcursor); write(#8,' ');
   if Number <> 0 then begin
      curp(Number); write(#8); grafchar(marker); Lastcursor:=Number;
   end;
end;

PROCEDURE setbank; forward;

procedure CountFreeBanks;
var a:integer;
begin  if Lastfunction=filenames then begin
  frebnk:=0; for a:=1 to HiBank do if BufName[a]=EmptyBuf then frebnk:=succ(frebnk);
  if frebnk=1 then frebnk:=-1;
end; end;

FUNCTION Select32(max:INTEGER): INTEGER;
label 99;
var a : INTEGER;
begin { select32 }
  Select32:=0; {C:='.'; marker:=chr(3); }
  repeat
    GrossC(C);
    case C of
      CE : begin goto 99 end;
     #24 : if Number<max then Number:=succ(Number);
     #05 : if Number>1 then Number:=pred(Number);
     #19 : if Number>16 then Number:=Number-16;
     #04 : if Number<=max-16 then Number:=Number+16;
     ' ' : if (Lastfunction=filenames) then begin
         if filesfound[Number][14] = marker then begin
           frebnk:=succ(frebnk); write(CL,' '); filesfound[Number][14] := ' '
         end else 
           if (filesfound[Number][14]=' ') 
              and ((frebnk>0) or (frebnk=-1)) then begin
             frebnk:=pred(frebnk); write(bell,CL); grafchar(marker); 
             filesfound[Number][14] := marker;
           end;
      end;
     'B' : if LastFunction<>filenames then begin
         LeftWindow:= (Number<=32); SetBank; Leftwindow:=true;
       end;
    end;
    if Number-Filofs>64 then begin Select32:=65; goto 99; end; {very tricky}
    if Number-FilOfs<1  then begin Select32:=-1; goto 99; end;
    curp(Number-FilOfs); 
    C:=conin; {if Lastfunction<>filenames then write(' ');}
  until C=CRET;
  Select32:=Number-FilOfs; 
  if (Lastfunction=filenames) and (filesfound[Number][14]<>Dirmarker) then
     filesfound[Number][14] := marker;
99:
end;

{---------------------------- D I S K -----------------------------------}
FUNCTION Disk_IO(D:Transfertype; var buf:blockptr; name:filename) : boolean;
label 99;
type 
  btype=packed record case integer of
      1: (B: bigbuffer);
      2: (Len: integer)
     end;
var
  b_ : record case integer of 
    1: (adr: long_integer);
    2: (p1: ^soundxptype);
    3: (p2: blockptr);
  end;
  CNAME:dosname;
  BufAdr,handle,size:long_integer;
  N,err:integer;
  okchar:filename;

  PROCEDURE testchar(var CF1:filename);
  label 99;
  begin
     C:= CF1[N]; if N>length(CF1) then goto 99;
     if POS(C, OKchar)<>0 then C:= '_';
     if not ( C in [' '..'~']) then C:= '$';
     CF1[N]:= C;
  99:  end;

  procedure SWAPB;
  var h:byte;
  begin h:=buf^.b[0]; buf^.b[0]:=buf^.b[1]; buf^.b[1]:=h; end;

begin  {Disk_IO}
  b_.p2:=buf; BufAdr:=b_.adr; StrToDos(name,cname);
  Disk_IO := false; err:=0; LastFunction:=none; { no error }
  Okchar:=' .?*:=,;';

  if FSB then begin
     FOR N:= 1 TO 8 do testchar(name); FOR N:= 10 TO 11 do testchar(name);
  end;
  
  if D= READ_ then begin
    handle:=FOPEN(cname,0);
    if handle<=0 then begin
       clear24; write(Bell,'Datei nicht gefunden ! '); getcapkey;
       Disk_IO:=true; goto 99;
    end; 
    case DataFormat of
    HMP,STEINBERG: begin
       if DataFormat=STEINBERG then BufAdr:=BufAdr+2;
       size:=iobuflen;
       if FREAD(handle,size,BufAdr)<=0 then err:=-1;
       if DataFormat=HMP then begin
         BUFLEN:= revint(buf^.Len); swapb;
         if Buflen>=IOBUFLen then begin 
           Disk_IO:=true; n:=fclose(handle); goto 99; 
         end;
       end else begin
         buf^.Len:=IOBUFlen-3; 
	   end;
    end;
    BEAM_TEAM: begin
       buf^.Len:=IOBUFlen-3; for n:=1 to 4 do buf^.SXC[n]:=CBANK[n]; 
       buf^.b[7]:=$20; buf^.b[8]:=0; BufAdr:=BufAdr+9{?};
       for n:=1 to 31 do begin
         size:=256;
         if FREAD(handle,size,BufAdr)<=0 then err:=-1;
         Bufadr:=Bufadr+128;
       end;
       size:=128; if FREAD(handle,size,BufAdr)<=0 then err:=-1;
       buf^.b[4106]:=$F7;
    end;
    end; {case}
    n:=fclose(handle);
  end else begin   {----------- WRITE------------ }
      handle:=fcreate(cname,0); if handle<=0 then begin Disk_IO:=true;goto 99;end;
      if FSB then begin
         clear24; write('     SPEICHERE SOUND: ', name);
        (* ofile^ := SoundBuf.B; put(ofile); close(ofile); (*swap?*)
      end else begin
(*       sectors:=buffer^.Len div 128 + 1;
         blockwrite(iofile,b_adr.p2^.B,sectors);  err:=err+ioresult;
*)
         size:=buf^.len; if size>IOBufLen then size:=IOBufLen;
         swapb; if FWRITE(handle,size,BufAdr)<=0 then err:=-1; swapb;
      end;
      err:=FCLOSE(handle);
  end; {write}
  Disk_IO:= (err<>0);
99:
end;

{-------------------------- end midi.inc --------------}
function equsxc(cc:string128; b:sxctype):boolean;
var n:integer; label 99;
begin
  equsxc:=true;
  for n:=1 to length(cc) do begin
     if cc[n]<>b[n-1] then begin equsxc:=false; goto 99; end;
  end;
99:
end;

PROCEDURE WriteSoundNames;
var n,nc,nline,xoffs,Number:byte; Name:DX_NAme;
begin
   if LeftWindow then begin
      n:=CurrentBank; gotoxy(4,1);
   end else begin
      n:=TestBank; gotoxy(61,1);
   end;
if FPRINT then begin
   FOR NLINE:=1 TO 8 do begin
     FOR Nc:=1 TO 4 do begin
       Number := shl(NLINE + (Nc-1), 3) ;
       Name:= Buffers[n]^.Bnk[Number].VoiceName;
       write(LST,Number:4, ' ', Name, '   ');
     end;
     writeln(LST);  FPRINT:=false;
   end;   {nline}
end else begin  { -------screen------- }
   inv_on;  write(' ', BufName[n], ' ':13-length(Bufname[N]) ); 
   inv_off; write(' (', n, ')');
   if (LastFunction<>soundnames) then begin
     LastFunction:=soundnames;
     if (BufName[n]<>EmptyBuf)
        and equsxc(CBANK, Buffers[n]^.sxc) then begin with Buffers[n]^ do
        for Number:=1 to 32 do BEGIN
          curp(Number);
          write(CTH,Number:4, Bnk[Number].VoiceName:11,' ' );
        end;
     end else 
        clearbox;
   end;
end;      { screen }
end;

PROCEDURE PrintBank;  { ------------ print sound names of a bank }
var CC_tmp:string100;
begin
 fillstr(CC_tmp, 79, '=');
 writeln(LST, 'YAMAHA DX-7 SOUND BANK      -->', BufName[CurrentBank], '<--');
 writeln(LST, CC_tmp )  ;  FPRINT:= true ;
 WriteSoundNames;
 fillstr(CC_tmp, 79,'-');
 writeln(LST, CC_tmp );  writeln(LST);  writeln(LST);
end;

{-------------------------------------------}
PROCEDURE InputNumber(imax:integer);
label 1,2,3,99;   
var CC2:string2; C1:char;
   PROCEDURE getnum;
   begin getcapkey;
      C1:=C; if not (C1 in [ '0'..'9']) then c1:=' ';
   end;
   PROCEDURE SetWindow; begin LeftWindow:= (Number<=32); end;

begin
1: clear24; write('SOUND NUMMER EINGEBEN : ');  Dummy:=true;
3: GetNum;
   case C of
     CRET: if dummy then goto 2;
      'B': begin SetWindow; setbank; goto 1; end;
      CE : begin Number:= 0; goto 99 end;
     #4,#5,#19,#24: begin Number:=select32(imax); goto 2 end;
   end;
  if Dummy then begin Dummy:=false; write(C1); CC2:= C1; goto 3; end;
   val(concat(CC2,C1),Number,N);
   if (n<>0) or not (Number in [0..imax]) then begin write(Bell); GOTO 1 end;
2: SetWindow;
99:
end;

PROCEDURE SendBlock;
begin
 n:=iifN(LeftWindow,CurrentBank,TestBank);
 BUFLEN:= Buffers[n]^.len;
 clear24; write('ICH SENDE ', buflen, ' Bytes...'); ClearKBD;
 MIDOUT(Buffers[n]^.C,BUFLEN);
 clear24; {writeln('FERTIG.');}
end;

{------------ midi1.inc ----------------}
procedure INTO(var Dest:soundxptype; to_:integer; 
               Src:intostring; from{1..N}, count:integer);
var n:integer;
begin
  if count=0 then count:=length(src);
  for n:=0 to pred(count) do begin
     dest[n+to_]:=ord(src[(n+from)]);
  end;
  {move_b(Adr_Byte(tmp.b)+from, Adr_Byte(dest)+to_, count)}
end;

{-------------------------- expand Bank > SOUNDBUF() }
PROCEDURE UnpackSound;
 { globals: LeftWindow, CurrentBank/TestBank, Number }
label 80,99;
var n,n1,n2:integer; ch:char;

   FUNCTION  FNASC(X:integer): byte;
   begin
      FNASC:=CDATA.b[N2+X-1];
   end;

begin
  n := iifN( LeftWindow, CurrentBank, TestBank );
    { hole Daten von 1 Sound aus der CurrentBank: }
  CDATA.b := Buffers[n]^.Bnk[succ(pred(Number) & $1F)].sec;
    { bef”rdere expandierte Daten nach SOUNDBUF: }
 with SOUNDBUF do begin
  Into(b, 2, concat(CSOUND,#1,#$1B), 1, 0);
  FOR N:=1 TO 6 do begin
    N1:= (N-1)*21+8; N2:= (N-1)*17+1;
    Into(b, N1, CDATA.s, N2+1, 11);
    b[N1+11]:= FNASC(11) & 3;
    b[N1+12]:= shr( FNASC(11) , 2);
    b[N1+13]:= FNASC(12) & 7;
    b[N1+14]:= FNASC(13) & 3;
    b[N1+15]:= shr( FNASC(13) , 2);
    b[N1+16]:= FNASC(14);
    b[N1+17]:= FNASC(15) & 1;
    b[N1+18]:= shr( FNASC(15) , 1);
    b[N1+19]:= FNASC(16);
    b[N1+20]:= shr( FNASC(12) , 3);
  end;  { for }
  N1:= 8 ;  N2:= 1;
  Into(b, N1+126, CDATA.s, N2+102+1, 9);
  b[N1+135]:= FNASC(111) & 7;
  b[N1+136]:= shr( FNASC(111) , 3);
  Into(b, N1+137, CDATA.s, N2+112+1, 4);
  b[N1+141]:= FNASC(116) & 1;
  b[N1+142]:= shr( FNASC(116) , 1 ) & 7;
  b[N1+143]:= shr( FNASC(116) , 4);
  Into(b, N1+144, CDATA.s,N2+117+1, 11);
  b[N1+156]:= $F7;     { eot-byte }
(*****)
{ CC:='';
{ for n:=1 to 10 do
{      CC:=concat(CC,CDATA.s[N2+117+N+1]);
{ gotoxy(60,23);write(CC); }
(****)
 end; { with SoundBuf }
  BUFLEN:= 165 ;  SOUNDBUF.len:= BUFLEN;
  Dummy:=CHSUM(SOUNDBUF.b);
    { Diese Daten k”nnen Midi gesendet werden, aber ! }
    { recordstruktur nicht greifbar daher: }
  unpack(SoundBuf.b1,USoundBuf.u,0);
(****************************
with usoundbuf do begin
n1:=0; clrscr;
repeat
  if keypressed then begin 
     read(ch); if ch=CE then goto 99;
  end;
  for n:=0 to 15 do begin 
    writehex(u[n+n1]); if(n+n1>166) then goto 80;
  end;
80:  write('  ');
  for n:=0 to 15 do begin
     ch:=chr(u[n+n1]); if (ch>=' ') and (ch<'~') then write(ch) else write('.'); 
     if(n+n1>=166) then goto 99;
  end;
  writeln; n1:=n1+16;
until false;
99: read(ch); frame;
end; 
(*****************) 80: ; 99:
end;

PROCEDURE SaveSound1 ;       {--------------------- save sound}
label 99;
begin
 FSB:= true; InputNumber(32); if Number<1 then begin FSB:= false; goto 99; end;
 UnPackSound;
 CF1:= concat( copy(CDATA.VoiceName,1,8), '.', copy(CDATA.VoiceName,9,2) );
(* ??? dummy:=Disk_IO(write_,SOUNDBUF.b,CF1); FSB:=false; ?????*)
99:
end;

PROCEDURE TransmitSound ;     {--------------------- transmit sound}
label 99;
begin
  writeln;  FSB:= false;
  repeat
    InputNumber(32); if Number<1 then begin clear24; goto 99; end;
    Putmarke;  UnpackSound;
{ dumpbank(Soundbuf.b,167);}
    MIDOUT(SOUNDBUF.b,BUFLEN);
  until false;
99:
end;

procedure WriteBlockNames; forward;

(*function STR1(x:integer) : char;*)

function PlusMin(x:integer) : char;
begin if x<0 then plusmin:='-' else plusmin:=' ' end;

procedure str(x,i:integer; var C:filename);
(*var x1,n:integer; cc:filename;*)
begin
(*  n:=0; x1:=abs(x);
  CC:='';
  repeat
    CC:=concat( digits[x1 mod 10 + 1], CC );
    x1:=x1 div 10;
    N:=succ(N);  {digits act.}
  until x1<=0;
  if x<0 then CC:=concat('-',CC);
  N:=i-length(CC);
  if N>0 then CC:=concat( copy('          ',1,N), CC);
*)  writev(C,x:i);
end;

{***************************** print sound ***********}
PROCEDURE Display1Sound(h01:integer);            {------ AUSDRUCK/PAR }

type string6 = string[8];
var COUT : string100;
    CURVL,CURVR,CSYNC : string2;
    FR_C,C_BP,CNOTE : filename;
    TASTE,OP,X,n,zeile : INTEGER;
    FINE,FR,ln10 : real;

   function WStr_00(x:integer):char;
   var c: string[5];
   begin
     if x>99 then write(CTH);
     if x>=10 then write(x:2) else write('0', x:1);
    { str(X+1000,C); Str_00 := copy(C,3,2); }
     WSTR_00:=#0;
   end;

(*   PROCEDURE WStr_N(X:integer);
   var c: string[5];
   begin {str(X,C); if X>=0 then C:=' '+C; Str_N:=C //
     if X>=0 then write(' ',X) else write(X); }
     write(X:2);
   end;
*)
   PROCEDURE PrintIt;
   begin
     if FPRINT then writeln(LST,COUT) ELSE writeln(COUT);
   end;

   PROCEDURE KeyToNote;  { ----- TASTE -> CNOTE }
   var okt:integer; CC:filename;
   begin
     okt:=succ(TASTE div 12); str(okt,2,CC);
     CNOTE := copy(CNOTES, 1 + shl( ((24+TASTE) MOD 12) , 1), 2);
     CNOTE := concat(CNOTE,CC);   {( 1+trunc(TASTE/12.0), C );}
   end;

begin {display1sound}
   zeile:=h01*13;
   ln10:=ln(10.0);
   with USOUNDBUF.PAR do begin
     {CNAME:= VoiceName;}
     for n:=1 to 10 do begin
        C:=VoiceName[N];
        if C < ' ' then C:='.';
        CNAME[N]:=C;
     end;
     box(1,zeile+2,80,zeile+10); gotoxy(0,zeile);
      write( 'Name:'); inv_on; write(' ',CNAME,' '); inv_off;
      write('    Algorithm:', WStr_00(Algo+1),
        '        Feedback:', WStr_00(Feedb), '':7 );
      inv_on;
      write(' ', BufName[iifN(Leftwindow,Currentbank,testbank)], '(', Number, ') ' );
      inv_off;
     writeln;
      write(' LFO -- Wave: ', copy(CWAVES,1 + 6 * (LFO_Wave&$F), 6), 
        ' Speed:', WStr_00(LFO_Speed), '  Delay:', WStr_00(LFO_Delay),
        '  Pmd:', WStr_00(LFO_PMD), '  Amd:', WStr_00(LFO_AMD) );
      write('  Sync:', copy(COFFON, 1 + 3*(LFO_Sync&1), 3),
        '  Mod-Pitch:', WStr_00(P_Mod) );
     gotoxy(1,zeile+3);
     writeln(
'     Frequency Det|   Rates  <EG>  Levels  |Rate-,Level-Scaling|Outp|Vel|Mod.A'
              );

     FOR OP:= 1 TO 6 do with OPER[OP] do begin
        CURVL:= copy(CURVES, succ( shl(CurveL&3,1) ), 2);
        CURVR:= copy(CURVES, succ( shl(CurveR&3,1) ), 2);
        if OscMode = 0  then begin
           if FreCo = 0 then
              X :=  (50 + shr( FreFine , 1) )
           else
              X :=  FreCo * (100 + FreFine);
           str(X,7,FR_C); {FR_C:=copy('      ',1,7-length(FR_C))+FR_C;}
           insert('.',FR_C,6);
        end else begin
           X :=  FreCo & 3;
           FINE := FreFine/100.0;   {--- (0 TO 99/100)  }
           FR:=exp(ln10 * (3+FINE)); 
           if FR<maxint then str( round( FR ),4, FR_C) else FR_C:='????';
           insert('.',FR_C,X+2);
    {       FR_C := concat(' ', copy(cnote,1,1+X), '.', copy(cnote,2+X,3-X), 'HZ');}
           FR_C := concat(' ', FR_C, 'HZ');
        end;
        TASTE :=  BreakPoint - 15 ; KeyToNote ;  C_BP:= CNOTE;
        {--------------printit   }
        write(#27,'COP', (7-OP):1);
        if OscMode = 0 then CC:= '  R' ELSE CC:= '  F';
        write(CC, FR_C, ' ', (Detune-7):2, ' |');
        FOR N:= 1 TO 8 do begin
           write(WStr_00(EG[N]), ' ');
           if N = 4 then write(' ');
        end;
       (* write(CL,'|');
        WStr_N(KeyRateSc); write('  ');     { rate scaling }
        write(CURVL, WStr_00(DepthL), ' ', C_BP, ' ', CURVR, WStr_00(DepthR),
          ' | ', WStr_00(OutLevel), ' |', WStr_N(Velocity), ' |');
        WStr_N(AM_Sens);
        writeln; *)
        write(CL, '|', KeyRateSc:2, '  ', CURVL, WStr_00(DepthL),
         ' ', C_BP, ' ', CURVR, WStr_00(DepthR), ' | ', WStr_00(OutLevel) );
        writeln(' |', Velocity:2, ' |', AM_Sens:2);
     end;  { OP- loop }

     writeln;
     TASTE:= Transpose; KeyToNote;
     write('  KeySync:', copy(COFFON, 1 + 3 * (OscSync&1), 3), 
        '  Transpose:', CNOTE, '  Pitch-Rates: ');
     FOR N:= 1 TO 8 do begin
        write(WStr_00(PEG[N]), ' ');
        if N = 4 then write(' Levels: ');
     end;
     if FPRINT then writeln(LST,#10,#10);
   end; { with SOUNDBUF.PAR }
end; {Display1Sound}   

PROCEDURE PrintSoundData;
label 99;
begin
  writeln; write(' Ausdrucken? (J/N) '); GetCapKey; FPRINT:=  C='J';
  if Fprint then rewrite(output,'LST:');
  repeat
     FSB:= false; InputNumber(32);
     if Number = 0 then begin
        rewrite(output,'CON:');
        FPRINT:=false; LastFunction:=none; frame;
        WriteSoundNames;
        goto 99;
     end;
     if FPRINT then Putmarke;
     UnpackSound;  {sound[Number] in SOUNDBUF.PAR}
     if not FPRINT then clrscr;
     Display1Sound(0);
  until false;
99:
end;


procedure BnkManager;
var Bank1Nr,Bank2Nr,Number1,Number2:integer;

function equ(var a,b:sector):boolean;
label 99;
var n:integer;
begin
   equ:=true;
   for n:=0 to 127 do if a[n]<>b[n] then begin equ:=false; goto 99 end;
99:
end;

procedure Vergleich(var Bank1,Bank2:DX_Bank);
var n,n1,n2 : integer;
begin
  LeftWindow:=true;
  for n1:=1 to 32 do begin
    curp(n1+32); write(' ',n1:2);
  end;
  for n1:=1 to 32 do begin
    n2:=0;
    if Bank1[n1].VoiceName = Bank2[n1].VoiceName then
       n2:=n1
    else begin
      for n:=1 to 32 do
        if Bank2[n].VoiceName = Bank1[n1].VoiceName then n2:=n;
    end;
    Curp(n1);
    if n2=0 then begin  { fehlt in Bank2 }
      write('?');
    end else begin
      write(' ', n1:2); curp(n2+32);
      if equ(Bank1[n1].sec, Bank2[n2].sec) then write('=') else write('#');
      write(n1:2);
    end;
  end;  { for n1 }
end;

procedure Writename(Bnknr, Number:integer);
begin write(Buffers[Bnknr]^.Bnk[Number].VoiceName); end;

PROCEDURE doCopy(var Bank1,Bank2:DX_Bank);
var  n:integer;
begin
  for n:=0 to 127 do Bank2[Number2].sec[n]:=Bank1[Number1].sec[n];
  curp(Number); write(Number2:3, Bank2[Number2].VoiceName:11);
end;

PROCEDURE CopySounds;
  label 1;
begin
repeat
  LastFunction:=manager;
  clears(20,24); gotoxy(28,20); write('C O P Y   S O U N D S');
{  gotoxy(5,24); write('Sound w„hlen, dann <RETURN> oder <ESC>');}

  gotoxy(0,22); write('Kopieren VON:  <->            ');
  LeftWindow:=true; CatchNumber(64);
  InputNumber(64); if Number=0 then goto 1;
  Bank1Nr := iifN(LeftWindow,CurrentBank,TestBank);
  LeftWindow:=true; PutMarke;  Number1:=succ(pred(Number) & $1F);
  gotoxy(14,22); writename(Bank1Nr,Number1);
  write('  (', BufName[Bank1Nr], ')' );

  write('  NACH:  <-> ');
  InputNumber(64); if Number=0 then goto 1;
  Bank2Nr := iifN(LeftWindow,CurrentBank,TestBank);
  LeftWindow:=true; PutMarke;  Number2:=succ(pred(Number) & $1F);

  doCopy(Buffers[Bank1Nr]^.bnk, Buffers[Bank2Nr]^.bnk);
until false;
1: C:=' ';  { exit would quit all the manager }
end;  { CopySounds }

procedure Comp2sounds;
label 1;
begin
repeat
  LastFunction:=manager;
  clears(20,24); gotoxy(31,20); write('VERGLEICHE 2 SOUNDS');

  gotoxy(0,22); write('W„hle Sound 1');
  LeftWindow:=true; CatchNumber(64);
  InputNumber(64); if Number=0 then goto 1;
  LeftWindow:=true; PutMarke;  Number1:=Number;

  gotoxy(0,22); write('W„hle Sound 2');
  InputNumber(64); if Number=0 then goto 1;
  LeftWindow:=true; PutMarke;  Number2:=Number;

  clrscr;
  leftwindow:=(Number1<=32); Number:=succ(pred(Number1) & $1F);
  UnpackSound; Display1sound(0);
{  inv_on; clears(12,12); inv_off;}
  leftwindow:=(Number2<=32); Number:=succ(pred(Number2) & $1F);
  UnpackSound; Display1sound(1);
  gotoxy(0,23); c:=conin;

  frame; lastfunction:=none;  
  leftwindow:=false; WriteSoundnames; lastfunction:=none;
  leftwindow:=true;  WriteSoundnames;
until false;
1: C:=' ';  { exit would quit all the manager }
end; {comp2sounds}

begin    { manager }
LeftWindow:=false; Clearbox; LastFunction:=manager;
Bank2Nr:=TestBank; WriteSoundnames;
repeat
  Number:=31;  clears(20,24);
  Lastfunction:=none; LeftWindow:=true;
  gotoxy(27, 1); write('  B A N K - M A N A G E R   ');
  gotoxy(15,21); write('<-, ->,  <B>=Bank w„hlen, <RETURN>=Sound senden');

  repeat
    LastFunction:=manager; InputNumber(64);
    Bank1Nr:=CurrentBank; Bank2Nr:=TestBank;
    n := iifN(LeftWindow,Bank1Nr,Bank2Nr);
    if Number<>0 then begin
       ClearKBD; Unpacksound; MIDOUT(SOUNDBUF.b,Buflen);
    end;
    LeftWindow:=true; PutMarke;
  until Number<=0;

  clears(21,24);
  gotoxy(5,21);  write(' C...copy          V...vergleiche B„nke   ');
  gotoxy(5,22);  write(' T...tauschen      X...vergl. 2 Sounds ');
  gotoxy(46,23); write('< >',CTH,CTH); getcapkey;
  case C of
     'V' : Vergleich(Buffers[Bank1Nr]^.bnk, Buffers[Bank2Nr]^.bnk);
     'C' : CopySounds;
     'X' : Comp2sounds;
   end;
until (C='0') or (C=CE);

CatchNumber(32); frame; Writeblocknames; LeftWindow:=true; WriteSoundNames;

end; { manager }


FUNCTION Files(var Dirmask: string32): char;
label 99;
type dirbuftyp = packed record
        data : packed array[0..29] of byte;
        name : dosname
     end;
Var MaskFCB,PathFCB:dosname; DirBuf:dirbuftyp;
    DRV,i,starpos,extpos:integer;
    extif:boolean;
    cc:filename;
    WorkPath:string32;
    
procedure setdta(var b:dirbuftyp); gemdos($1A);
function dirfirst(var name:dosname;attrib:integer):integer;gemdos($4E);
function dirnext:integer;gemdos($4F);

function ParsPath(var Ctest,Cpath:string32):boolean;
label 1;
var n:integer;
begin 
Cpath:=''; ParsPath:=false;
for n:=length(Ctest) downto 1 do if Ctest[N]='\' then goto 1;
1: 
if Ctest[N]='\' then begin
   Cpath:=copy(Ctest,1,N); Ctest:=copy(Ctest,N+1,length(Ctest)-N);
   ParsPath:=true;
end;
end;

PROCEDURE ReadNames;
label 99;
var n,test:integer;
begin
  somany:=0;
  setdta(DIRBUF);
  NoBlanks(Dirmask);  gross(Dirmask);
   {----erkenne Drivespec. und setze Drive}
  N:=pos(':',Dirmask) ; DRV:=ord(Dirmask[0])-$40;
  if (N=2) and (DRV in [1..16]) then begin
     if setdrv(pred(DRV))<0 then begin
        clear24; write('Ungltiges Laufwerk!',bell); delay(0.6); goto 99;
     end;
     WrkDRV:=copy(Dirmask,1,2);
  end else begin
   { DRV:=setdrv(drive);} 
     DRV:=0; WrkDRV:=ODrive;
  end;
   {----erkenne path_spec. und setze path}
  if ParsPath(DirMask,WorkPath) then begin
    StrToDos(WorkPath,PathFCB);
(*clear24;writeC(PathFCB);write(']');*)
    if setpath(PathFCB)<0 then begin
      clear24; write('Ungltiger Pfad!',bell); delay(0.6); goto 99;
    end;
  end;
   {----------- lese Dateinamen }
  if ''=Dirmask then Dirmask:='*.*';
  StrToDos(Dirmask,MaskFCB);
  n:=dirfirst(MaskFCB,17); somany:=0;
  while (n=0) and (Somany<Maxdir) do begin
     Somany:=succ(Somany);
     DosToStr(Dirbuf.name, FilesFound[somany]); {name+'.'+ext;}
     if Dirbuf.data[21]&$10 > 0 then begin
       FilesFound[somany][14]:=DirMarker;
     end;
     n:=dirnext;
  end;
99:
end; {readnames}

procedure DispFiles;
var n,i:integer;
begin
  LeftWindow:=false; clearbox; Leftwindow:=true;
  if somany>64 then n:=64 else n:=somany;
  For i:=1 to n do begin
     curp(i); write(CL);
     grafchar(Filesfound[i+FilOfs][14]); write(FilesFound[i+FilOfs]:15);
  end;
end;

begin {------ files ------}
  FILES:=CE; FilOfs:=0; clears(20,24);
  if (DirMask<>'') or (Somany=0) then begin
    for i:=1 to somany do Filesfound[i][14]:=' ';
    ReadNames;
  end;
  clearbox; if Somany<17 then box(1,2,20,Somany+3);
  getpath(PathFCB,0); DosToCC(PathFCB, WorkPath); NoBlanks(WorkPath);
  gotoxy(2,1); write('  DATEIVERZEICHNIS     ');
  DispFiles;
  LastFunction:=filenames;
  gotoxy(28,20); write('B Ž N K E   L A D E N'); 
  gotoxy(1,22); write(' Verzeichnis ');
  inv_on; write(wrkdrv, WorkPath, '\', Dirmask ); inv_off;
  gotoxy(0,23); write( somany:4, ' Dateien,   Auswahl:  ');
  grafchar(#4); write(', '); grafchar(#3); write(', Leertaste, RETURN, ESC');

  Number:=1; C:='.'; CountFreeBanks;
  repeat 
    N:=select32(Somany); 
    if N>64 then begin FilOfs:=FilOfs+32; DispFiles; end;
    if N<0 then  begin FilOfs:=FilOfs-32; DispFiles; end;
  until N in [0..64];
  FilOfs:=0; Number:=1;
  if N<>0 then begin
    IF Filesfound[N][14]=DirMarker then begin
      CC:=copy(Filesfound[N],1,12); Noblanks(CC); CC:=concat(CC,'\');
      StrToDos(CC,PathFCB);
      if setpath(PathFCB)<0 then begin
{ gotoxy(0,24); write('<'); writeC(pathfcb); write('>?'); delay(1.7);}
      end;
      FILES:='D'; CF:='*.*';
      goto 99;
    end else
     {CC:=concat(WrkDRV,FilesFound[N]);
      NoBlanks(CC);}
      FILES:='+';
  end ;
  clear24; LeftWindow:=false; ClearBox; LeftWinDow:=true; ClearBox;
  WriteSoundNames; WriteBlockNames;
99:
end;

PROCEDURE INIT1 ;
var drive: integer;
    spaces31:string[32];
(*   PROCEDURE CopyOVL;
   begin { if drive P: selectable }
     Drive:=BIOSHL(8,Drive);
     assign(IFILE,ODrive+OvrFName); reset(ifile);
     ODrive:='P:';
     assign(OFILE,ODrive+OvrFName); rewrite(ofile);
     N:=filesize(ifile);
{$I-} blockread(ifile,Buffers[1]^,N);
      blockwrite(ofile,Buffers[1]^,N); {$I+}
     if ioresult<>0 then begin close(ofile); Odrive:=''; exit; end;
     close(ifile); close(ofile);
     ovrdrive(ord(ODrive[1])-$40); { tell runtime to find OVR in ramdisk }
   end;
*)
begin
{$P-,R-}
  midirecptr := iorec(2); sysmidi := midirecptr^;
  IOintPtrs := getvec; SysMintPtr := IOintPtrs^.midin;
{$P=,R=}
  LastFunction:=none; LastCursor:=1; Number:=1; EmptyBuf:=' - - - - - -';
  LeftWindow:=true;
  N:=1;
  while (N<=SetHiBank) and (memavail>sizeof(bigbuffer)) do begin
    new(Buffers[N]); {write(memavail:10);} BufName[N]:=EmptyBuf;
    Hibank:=N; N:=succ(N);
  end;
  CHiBank:=chr(HiBank+$30);
  Bufptr:=Buffers[1]; CurrentBank:=1; TestBank:=1;
  Somany:=0; FilOfs:=0;
  BUFLEN:= IOBUFlen-1;
  CYAMAHA:= concat(#$F0,#$43) ;  CSOUND :=concat(CYAMAHA,#0,#0);
  CBANK :=  concat(CYAMAHA,#0,#9);
  CNOTES:= ' CC# DD# E FF# GG# AA# H'; CURVES:= '-L-E+E+L';
  CWAVES:= 'TRIANGSAW-DNSAW-UPSQARE SINE  S/HOLD' ; COFFON:= 'OFF ON';
  (*digits:= '0123456789ABCDEF';*)
  spaces31:='                               ';
  spaces:=concat(spaces31,spaces31,spaces31,spaces31);
  spaces:=concat(spaces,spaces);
  CDATA.s:=copy(spaces,1,130); SoundBuf.s:=copy(spaces,1,167);
  CNAME:=copy(spaces,1,10);
  DataFormat:=HMP;
(* Drive:=getdrv;
(* ODrive:=chr(Drive+$41)+':';
  if (Drive<>15) and (BIOSHL(8,15)<>0) then CopyOVL; { P: }
*)  rewrite(LST,'lst:');
end;

PROCEDURE EditSound;      {  --------- editor ----- }
   label 99;
   var C1:string[10];
       CDATA1: DX_Sound;
       n:integer;
begin
   repeat
     clears(20,24); write(' ':20, 'MINI - EDITOR', ' ':30, CNAME);
     GOTOXY(2,20);  write('0...Ende                              ');
     GOTOXY(2,21);  write('1...Operatoren umordnen               ');
     GOTOXY(2,23);  write('                 ->                   ');
     GOTOXY(22,23);
     repeat  GetCapKey until (C in ['0', '1']);
     if C='0' then goto 99;
     repeat
       gotoxy(0,23); clreol;
       write('NEUE REIHENFOLGE DER OPERATOREN: (123456) '); readln(C1);
     until length(C1)=6;
     unpack(Soundbuf.b1,USoundBuf.u,1);
     CDATA1:=USoundbuf.PAR;
     FOR N:= 1 TO 6 do
       USoundbuf.PAR.oper[N]:=CDATA1.oper[ 7 - ord( C1[7-N] ) + $30 ];
{      mid$(CDATA,(N-1)*21+N1):= mid$(B$,( 6-VAL(copy(C1,7-N,1)) )*21+N1,21);}
     pack(USoundBuf.u,1,Soundbuf.b1);
     Bufptr^.b:=SoundBuf.b;
     dummy:=CHSUM(Bufptr^.b); SendBlock;
   until false;
99:
end {EditSound};

{------------------------------- handler for YAMAHA data (bank&sound)}
PROCEDURE DoYAMAHA ;
label 99;
var Ctmp:packed record CASE INTEGER of
        1:(s:string255); {mem!}
        2:(b:packed array[0..254]of byte);
    end;
    BPOS,n:integer;
begin
 ctmp.s:=copy(spaces,1,127);
 ctmp.s:=concat(ctmp.s,ctmp.s); 
 for n:=1 to 250 do Ctmp.s[n]:=chr(Bufptr^.b[n-1]);

 BPOS:= pos(CSOUND,Ctmp.s)+5;
 if BPOS<>5 then begin   { -------single sound data: }
     CNAME:= copy(Ctmp.s,BPOS+146,10);
     clears(20,24); write('YAMAHA DX-7 SOUND DATA      -->', CNAME, '<--');
     if CHSUM(Bufptr^.b) then write('- CHECKSUM ERROR !', Bell);

     GOTOXY(20,23); write('EDITOR (J/N) ? ');  GetCapKey;
     if  (C='J') then if OvrHere(Oeditsound) then begin
        SoundBuf.B:=Bufptr^.B;
        EditSound;
        Bufptr^.B:=Soundbuf.B;
     end;

 end else begin
     BPOS:= pos(CBANK,Ctmp.s);
     if BPOS=0 then begin BPOS:=8; write(bell); goto 99; end;
     if BPOS>3 then with Bufptr^ do begin
        { move_B(Bufptr^.b[pred(BPOS)],Bufptr^.b[2],IOBUFLen-BPOS);}
        for n:=0 to iobuflen-BPOS-1 do
           b[2+n]:=b[pred(BPOS)+n];
        Len:=Len-BPOS+3; {-(pred()-2)}
     end;
     Bpos:=8;     {1,2 = Len!}
     if CHSUM(Bufptr^.b) then begin 
       clear24; write('- CHECKSUM ERROR !', Bell); delay(0.7); 
     end;
     WriteSoundNames;
 end;
99:
end;

PROCEDURE WriteBlockNames;
var n:byte;
begin
   gotoxy(51,7); write('GELADENE BŽNKE:');
   for N:=1 to HiBank do begin
   GOTOXY(51,N+8); write (N, ') ', BufName[N], '':5)
end; end;

PROCEDURE ReceiveBlock;
label 99;
begin
 clears(20,24); gotoxy(1,21);
 if BufName[CurrentBank]<>EmptyBuf then begin
   writeln(' Achtung, ', Bufname[CurrentBank], '(', CurrentBank:1, ')', 
           ' wird vorher gel”scht!');
   write  ('  OK? (J/N)'); getcapkey;
   if C<>'J' then goto 99;
   clears(20,24); gotoxy(1,21);
 end;
 writeln(' Ich warte auf DX-7 SoundDaten .....');
 write  (' (Zum Abbrechen Taste drcken)  ') ;
 BUFLEN:= IOBUFlen-1;
 MIDIN(Buffers[CurrentBank],BUFLEN) ;
 if BUFLEN=0 then
   BufName[CurrentBank]:=EmptyBuf
 else begin 
   BufName[CurrentBank]:= ' (MIDI)     ';
 end;
 Writeblocknames;
 Bufptr^.Len:= BUFLEN;
 clear24; write(' --->  ',BUFLEN, ' Bytes empfangen!'); delay(0.6);
 LastFunction:=none; DoYAMAHA;
99:
end;


FUNCTION Blockisfree(var N:byte):boolean;
label 99;
begin
  Blockisfree:=false;
  while N<=HiBank do begin
     if BufName[N]=EmptyBuf then begin
        Blockisfree:=true; goto 99;
     end;
     N:=succ(N);
  end;
  99:
end;

PROCEDURE LoadBlock;
label 99;
var a,where:byte;
 FUNCTION Filetoload:boolean;
 label 99;
 begin
  Filetoload:=false;
  while Number<=Somany do begin
    if FilesFound[Number][14] = marker then begin
       FilesFound[Number][14] := ' '; Filetoload:=true;
       goto 99;
    end;
    Number:=succ(Number);
  end;
  99:
 end;

begin
 FSB:=false; CF:='';
 if not OvrHere(Ofiles) then goto 99;
 CC:='SUCHBEGRIFF   (zB. "A:*.BNK", "dx7\")  '; GetName;
 repeat
  C:=FILES(CF)
 until C<>'D';
 if C=CE then goto 99;

 where:=1; Number:=1;
 while Filetoload do begin
    CF := concat(WrkDRV, FilesFound[Number]);
    NoBlanks(CF);
    if Blockisfree(where) then CurrentBank:=where; 
    Bufptr:=Buffers[CurrentBank];
    if Disk_IO(READ_,Bufptr,CF) then begin
      clear24; write(bell,CF:20, '  nicht geladen !'); CF:=EmptyBuf; delay(0.7);
    end;
    BufName[CurrentBank]:=CF;
    LastFunction:=none; DoYamaha; WriteBlocknames;
 end;
 99:
end;

PROCEDURE SaveBlock;
label 99;
begin
 FSB:=false; CF:=BufName[CurrentBank];
 CC:='NAMEN ZUM ABSPEICHERN EINGEBEN '; GetName;
 noblanks(CF); if CF='' then goto 99;
 BufName[CurrentBank]:=CF;
 clear24;
 if Disk_IO(write_,Buffers[CurrentBank],CF) then
    write(bell,'Diskette voll!')
 else
    write('OK.');
 99:
end;


PROCEDURE SetBank;
label 99;
var nn:integer;
begin
  N:=CurrentBank;
  repeat C:=conin until c in [ CE,'1'..CHiBank ];
  if c=CE then goto 99;
  nn:=ord(c)-$30; write(c);
  if LeftWindow then CurrentBank:=nn else TestBank:=nn;
  Bufptr:=Buffers[nn];
{  if (*(LastFunction = soundnames) and*) (N<>CurrentBank) then begin}
  LastFunction:=none; WriteSoundNames; LastFunction:=none;
{  end;}
99:
end;

Procedure Rename;
  PROCEDURE do_rename(var WBank:DX_Bank);
  var n:integer; 
  begin  with WBANK[Number] do begin
      repeat
        curp(Number); write(CTH, Number:4, ' '); save_cursor;
        repeat until keypressed; write('          ');restore_cursor;
        delay(0.1); save_cursor;
        readln(CC); restore_cursor;
        if CC='' then begin CC:=VoiceName; write(CC); end;
      until length(CC)<=10; CC:=concat(CC, '          ');
      {move(CC[1],VoiceName[1],10);}
      for n:=1 to 10 do VoiceName[N]:=CC[N];
  end; end;
begin {Rename}
  Number:=1; C:='.';
  Number:=select32(32);
  while Number<>0 do begin 
    do_rename(Buffers[CurrentBank]^.bnk); Number:=select32(32) 
  end;
end;

PROCEDURE Loesch;
label 99;
begin 
  WriteBlockNames;
repeat clear24; write('L”schen Bank Nr.:'); getcapkey;
  if C = CE then begin clear24; goto 99; end;
  if C in ['1'..CHiBank] then begin
     BufName[ord(C)-$30]:=EmptyBuf; WriteBlockNames;
  end;
until false; 
99: LastFunction:=none;
end;

procedure SetFormats;
begin
  clears(20,24); gotoxy(0,21); write(' Auswahl: Lesen anderer DX-7 Formate');
  gotoxy(10,22); write('1..Standard    3..Steinberg');
  gotoxy(10,23); write('2..Beam-Team');
  gotoxy(10,24); write('< >',CL,CL);
  repeat getcapkey  until C in ['1'..'3',CE];
  case C of
  '1': DataFormat:=HMP;
  '2': Dataformat:=BEAM_TEAM;
  '3': Dataformat:=STEINBERG;
  end;
end;

PROCEDURE DX_Menu;
label 21,99;
begin 
  DoYAMAHA; clears(20,24);
  if BufName[CurrentBank]<>EmptyBuf then repeat
     GOTOXY(1,20);  writeln('  0...Ende              3...Bank senden              B...Bank w„hlen');
     GOTOXY(1,21);  writeln('  1...Sound senden      4...Bank ausdrucken');
     GOTOXY(1,22);  writeln('  2...Sound ausdrucken  5...Einzelsound abspeichern');
     GOTOXY(1,23);  writeln('  6...neuer SoundName                      < > ');
21:  GOTOXY(45,23); GetCapKey;
     case C of '0',CE: begin writeblocknames; goto 99 end;
               '1': TransmitSound;    '4': PrintBank;
               '2': if OvrHere(Oprintsounddata) then PrintSoundData;
               '5': SaveSound1;       '6': Rename;
               '3': SendBlock;        'B': begin SetBank; goto 21; end;
         otherwise: goto 21;
     end;
  until false
{else
  clear24; write(bufname[CurrentBank], ' bank:', CurrentBank);}
;  99:   
end;

procedure main;
label 11,99;
{------------------------main--------------------}
begin

{OvrFName:='MTEST.000'; ODrive:=''; OvrActive:=Onone;
if OvrHere(Oinit1) then INIT1 else halt;}

getpath(OldPath,0);
drive:=getdrv; ODrive := concat( chr(Drive+$41), ':' );

{$P-,R-}
Applmidi := midirecptr^; ApplMintPtr := IOintPtrs^.midin;
{$P=,R=}
hide_Mouse;
{W_title:='PHHHEW!';
{W_handle:=New_Window(G_All,W_title,0,0,0,0);
{Open_Window(W_handle,0,0,0,0);}
   { get_screen(screenmem);         { !! mem 32k !! }
Frame; Cur_on; 
Lastfunction:=none;
repeat
   clears(20,24); WriteSoundNames;
   GOTOXY(1,20);  write('  0...Ende            D...Disk Laden               B...Bank w„hlen  ');
   GOTOXY(1,21);  write('                      A...Abspeichern              X...Sound-Manager');
   GOTOXY(1,22);  write('  E...Empfangen       F...Fremdformate (F=' );
       write( succ(ord(Dataformat)):1, ')' );
   GOTOXY(1,23);  write('  S...Senden          M...Bank-Manager     < > ');
11:
   GOTOXY(45,23);  GetCapKey;
   case C of '0': begin show_Mouse; QuitToSystem; goto 99; end;
             'E': ReceiveBlock;     'S': SendBlock;
             'L': Loesch;           'F': SetFormats;
             'D': LoadBlock;        'A': SaveBlock;       'X': DX_Menu  ;
             'B': begin SetBank; goto 11; end;
             'M': if OvrHere(Obnkmanager) then BnkManager;
 '?': dumpbank(Buffers[CurrentBank]^.b,IOBuflen);
       otherwise: goto 11;
   end;
until false;
99:
end;

{------------------- install ---------------}
begin

ap_id:=init_gem;
if ap_id>0 then begin
{ACC:}
  L_acc:=true;
  AccName:='  DX7 - LOADER ';
  menu_id:=Menu_register(ap_id,AccName);
  INIT1;
  repeat
   event:=Get_Event(E_message,0,0,0,0, false,0,0,0,0, false,0,0,0,0,
             msg,d,d,d,d,d,d);
   if msg[0]=AC_Open then main;
  until false;
{}
end;

 {no ACC:  L_acc:=false; INIT1; main; 
 { don't forget &A options at beginning}

write(' !! OOPS !!',#7);
end.
