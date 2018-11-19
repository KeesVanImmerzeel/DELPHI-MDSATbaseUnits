unit uDCfunc;
{-Definieert functies en data-typen die verband houden met het gebruik van
  discontinuiteitsfuncties}

interface

uses
  Classes, ExtParU, Dialogs, system.SysUtils, Math;
{.$define test}

{Const}
  {-Foutcodes}
  {cTooManyDCfunctions = -10100;}

Type
  Tcontext = ( Algorithme, ProfileReset, ProfileNext, Trigger, UpdateYstart );
  TdcRec = Record
    State: Boolean;
    Value: Double;
  end;
  TdcArray =  Array of TdcRec;
  TDiscontType   = ( Discontinuity, DomainBoundary );
  TdcCompareType = ( GT, GE, LT, LE );
  PModelProfile = ^TModelProfile;
  TModelProfile = Class( TObject )
    private
    protected
    public
      Current, Next: TdcArray; {- Deze arrays zijn Zero based!}
      DCfuncSetForStateChange: Integer;

      Constructor Create( const I_NrOfDCfunctions: Integer );
      Destructor Free; Virtual;

      Function NrOfDCfunctions: Integer; Virtual;
      Function DCfunc( const DiscontType: TDiscontType;
                       const x: Double; const dcCompareType: TdcCompareType;
                       const y: Double; const Context: TContext;
                       const i: Integer; var Triggered: Boolean ): Double; Virtual;
        {-Als discontinuiteit is aangetroffen, Triggered = true, anders false }
        {-Als Trigered = true dan bevat result de nieuwe weerde van x,}
        {-anders bevat result de oorspronkelijke waarde van x}
        {-Discontinuiteits-functie; 0 <= i <= NrOfDCfunctions-1! }
      Function StateHasChanged( const i: Integer ): Boolean; Virtual;
        {-Discontinuiteits-functie; 0 <= i <= NrOfDCfunctions-1! }
      Function NrOfStateChanges: Integer; Virtual;
      Function HasChanged: Boolean; Virtual;
        {-True als NrOfStateChanges > 0 }
      Function DCfuncWithStateChange: Integer; Virtual;
        {-Nr. van de (eerst-voorkomende) DC-functie (in de DC-array) met
          State-change. Als er geen state-change is, dan is het resultaat van
          deze functie -1; anders: 0 <= Result <= NrOfDCfunctions-1! }
//      Procedure MoveOn; Virtual;
        {-Maakt het ModelProfile.Current gelijk aan ModelProfile.Next}
      Function AverageMomentOfStateChange( const xs: Double; var hdid: Double ): Double;
        {-Gem. moment waarop het teken van de discontinuiteitsfuncties omklapt.
          Als 'HasChanged=true', dan: xs < Result < xs+hdid; anders:
          Result=xs+hdid}
      Function MomentOfStateChange( const i: Integer; const xs: Double; var hdid: Double ): Double;
        {-Moment waarop het teken van de discontinuiteitsfunctie i omklapt.
          0 <= i <= NrOfDCfunctions-1. Als 'HasChanged=true',
          dan: xs < Result < xs+hdid; anders: Result=xs+hdid}
  end;

{-Aantal discontinuiteitsfuncties op EP-array}
Function Get_nDC( var EP: TExtParArray ): Integer;

implementation

Function Get_nDC( var EP: TExtParArray ): Integer;
begin
  with EP[ cEP0 ].xInDep do
    Result := Trunc( Items[ 0 ].GetValue( cmpnDc, 1 ) );
end;

Function TModelProfile.DCfunc( const DiscontType: TDiscontType;
                       const x: Double; const dcCompareType: TdcCompareType;
                       const y: Double; const Context: TContext;
                       const i: Integer; var Triggered: Boolean ): Double;
var
  aDCrec: TdcRec;
  CompareResult: Boolean;
  {$ifdef test}
  f: TextFile;
  {$endif}
const
  cTiny = {1e-30}MinDouble;
begin
  {$ifdef test}
  AssignFile( f, 'uDCfunc.log' ); Rewrite( f );
  {$endif}

  {-Default behaviour}
  Triggered := False;
  Result := x;
  Case dcCompareType of
    GT: CompareResult := ( x > y  );
    GE: CompareResult := ( x >= y );
    LT: CompareResult := ( x < y  );
    LE: CompareResult := ( x <= y );
    else
      CompareResult := true;
  end;

  with aDCrec do begin
    State  := CompareResult;
    Value  := x - y; {-Waarde discontinuiteitsfunctie}
  end;

  Case Context of
    {-Aan het begin van het integratieinterval wordt het huidige model-
      profiel vastgelegd in Current en Next.}
    ProfileReset:
      begin
        Move( aDCrec, Next[ i ], SizeOf( TdcRec ) );
        Move( aDCrec, Current[ i ], SizeOf( TdcRec ) );
//        Result := False; {-No Trigger actions}
  {$ifdef test}
        Writeln( f, 'ProfileReset i= ', i );
  {$endif}
      end;
    Algorithme:
      begin
//        Case DiscontType of
//          Discontinuity:      Result := Current[ i ].State; {-Hou vast aan huidige profiel status}
//          DomainBoundary: Result := False; {-Doorloop 'trigger' code niet in algorithme context}
//        end;
//        Result := false; {-No Trigger actions}
      end;

    {-Leg a.h. eind van het integratieinterval het modelprofile vast in Next.}
    ProfileNext:
      begin
        Move( aDCrec, Next[ i ], SizeOf( TdcRec ) );
//        Result := False;
  {$ifdef test}
        Writeln( f, 'ProfileNext i= ', i );
  {$endif}
      end;

    Trigger: begin
      Triggered := ( i = DCfuncSetForStateChange );{-Set by DCStepRout}
      if Triggered then begin {-Allow optional trigger actions in speed procedure}
  {$ifdef test}
        Writeln( f, 'Trigger i= ', i );
  {$endif}
        Case DiscontType of
          Discontinuity: begin
              with Current[ i ] do begin
                State := not State;
                Value := -Value;
              end;
              Move( Current, Next, SizeOf( Current ) );
              {$ifdef test}
              Writeln( f, 'Discontinuity' );
              {$endif}
            end;
          DomainBoundary: begin
            {$ifdef test}
            Writeln( f, 'DomainBoundary' );  {-Do not change current modelprofile}
           {$endif}
            end;
        end; {-case}
        Result := y + sign( Current[ i ].Value ) * cTiny;
        DCfuncSetForStateChange := -1;
      end else {-Not Trigered}
        {Result := false};
    end;
  end; {-Case Context}

  {$ifdef test}
  CloseFile( f );
  {$endif}

end; {-Function DCfunc}

Constructor TModelProfile.Create( const I_NrOfDCfunctions: Integer );
begin
  Inherited Create;
  SetLength( Current, I_NrOfDCfunctions );
  SetLength( Next, I_NrOfDCfunctions );
  DCfuncSetForStateChange := -1;
end;

Destructor TModelProfile.Free;
begin
  SetLength( Current, 0 );
  SetLength( Next, 0 );
//  Inherited Free;
end;

Function TModelProfile.NrOfDCfunctions: Integer;
begin
  Result := High(Current) + 1;
end;

Function TModelProfile.StateHasChanged( const i: Integer ): Boolean;
begin
  Result := ( Current[ i ].State  <>  Next[ i ].State  );
end;

Function TModelProfile.NrOfStateChanges: Integer;
var
  i, n: Integer;
begin
  Result := 0;
  n      := NrOfDCfunctions;
  for i:=0 to n-1 do
    if StateHasChanged( i ) then
      Inc( Result );
end;

Function TModelProfile.HasChanged: Boolean;
begin
  Result := ( NrOfStateChanges > 0 );
end;

//Procedure TModelProfile.MoveOn;
//var
//  i, n: Integer;
//begin
//  n := NrOfDCfunctions;
//  for i:=0 to n-1 do
//    if StateHasChanged( i ) then begin
//      ShowMessage( 'MoveOn ' + IntToStr( i ) );
//      with Current[ i ] do begin
//        State := not State;
//        Value := -Value;
//      end;
//    end;
//end;

Function TModelProfile.MomentOfStateChange( const i: Integer; const xs: Double;
          var hdid: Double ): Double;
begin
  if StateHasChanged( i ) then
    hdid := hdid * abs( ( Current[ i ].Value / ( Next[ i ].Value - Current[ i ].Value ) ) );
  Result := xs + hdid;
end;

Function TModelProfile.AverageMomentOfStateChange( const xs: Double;
                                                   var hdid: Double ): Double;
var
  i, n, m: Integer;
  SumHdid, SumOfMomentsOfStatChange, h: Double;
begin
  n      := NrOfDCfunctions;
  m      := 0;         {-Aantal DC functions met state change in interval x=xs tot x=xs+hdid}
  Result := xs + hdid / 2; {-Default result (AverageMomentOfStateChange)}
  if ( n > 0 ) then begin
    SumHdid                  := 0;
    SumOfMomentsOfStatChange := 0;
    for i:=0 to n-1 do begin
      if StateHasChanged( i ) then begin
        Inc( m );
        h         := hdid;
        SumOfMomentsOfStatChange := SumOfMomentsOfStatChange + MomentOfStateChange( i, xs, h );
        SumHdid   := SumHdid + h;
      end;
    end;
    if ( m > 0 ) then begin
      Result := SumOfMomentsOfStatChange / m;
      hdid   := SumHdid / m;
    end;
  end;
end;

Function TModelProfile.DCfuncWithStateChange: Integer;
var
  i, n: Integer;
begin
  Result := -1;
  n      := NrOfDCfunctions;
  i      := 0;
  while( i <= (n-1) ) and ( Result = -1 ) do begin
    if StateHasChanged( i ) then
      Result := i;
    Inc( i );
  end;
end;

end.
