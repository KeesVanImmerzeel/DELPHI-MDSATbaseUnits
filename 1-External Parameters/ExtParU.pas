Unit ExtParU;

Interface

{.$Define testUpdate}

Uses
  SysUtils, LargeArrays, XYTable, XYTableList, UDoubleMatrixList, Math, DUtils,
  IniFiles, uError, Classes ,dialogs, System.UITypes;

Type
  PExtPar = ^TExtPar;
  TExtPar = Class( TObject )
  private
  protected
  public
    xDep: TxyTableList;             {-tijdsafhankelijk waarden}
    xInDep: TDoubleMatrixList;      {-tijdsonafhankelijk waarden}
    Constructor Create; reintroduce;
    Destructor  Destroy; override;
    Function ReadxDepFromTextFile( var f: TextFile ): Integer; virtual;
      {Adds xDep-tables stored in text-files. Call Create first!}
    Function ReadxInDepFromTextFile( var f: TextFile ): Integer; virtual;
      {Adds xInDep-tables stored in text-files. Call Create first!}
    Function DxTilNextYChange( const x: Double;
             const Direction: TDirection ): Double; Virtual;
      {-Distance dx until next change in Y. Value may depend on parameter
        'Direction' in 'xyTable.pas'. Array's must be sorted (internally) ascending on X! }
    Procedure WriteToTextFile( var f: TextFile ); Virtual;
    Procedure ReadFromTextFile( var f: TextFile ); Virtual;
    Function SaveToStream( SaveStream: TStream ): Boolean; Virtual;
    Function LoadFromStream( LoadStream: TStream ): Boolean; Virtual;
    Function Clone: TExtPar; Virtual;
      {-Returns a new instance of the TExtPar-class and copies the data into it}
    Function Update( var fIniFile: TiniFile; var ExtParBuf: TExtPar;
                     var UpdateCount, IErr: Integer ): Boolean; Virtual;
      {-Vervang 1-of meer tabellen in TExtPar op basis van fIniFile. De update-
        tabel mag eventueel van een ander type zijn dan de oorspronkelijke
        tabel. Wees hier echter toch voorzichtig mee omdat een model soms uitgaat
        van een bepaald type tabel. UpdateCount bevat het aantal tabellen dat is
        ge-update. In 'ExtParBuf' zijn, t.b.v. 'Restore') de tabellen opgeslagen
        die zijn vervangen.}
    Function Restore( var fIniFile: TiniFile; var ExtParBuf: TExtPar;
                     var RestoreCount, IErr: Integer ): Boolean; Virtual;
      {-Herstel de tabellen van TExtPar die met 'Update' waren vervangen.
        RestoreCount bevat het aantal tabellen dat is hersteld (moet in principe
        gelijk zijn aan 'UpdateCount'. }
    Function HasData: Boolean; Virtual;
      {-True als (xDep.count>0) en/of (xInDep.count>0)}
  end;

  TExtParArray = Array of TExtPar;
  TBootEpArrayOption =
    ( cBootEPFromTextFile,   {-Read&Initialise&Evaluate EP-array; set reserved values}
      cReEvaluateEpArray );  {-ReEvaluate EP-array}
  TBootEPArray = Function(
    const EpDir: String;                         {-Directory with *.EP$-files}
    const BootEpArrayOption: TBootEpArrayOption; {-Ref. 'TBootEpArrayOption'}
    var EP: TExtParArray ): Integer;

Function DxTilNextYChange( const x: Double; const Direction: TDirection;
                           EP: TExtParArray ): Double;

Function GetNrOfDepVariables( const EP: TExtParArray ): Integer;
  {-Geeft het aantal afhankelijke variabelen}

Const
  {-Constanten (zie ook 'UDSmodel')}

  cMaxClaim = 5;
  {-Max. value of nr. of columns claimed by dep.variable on ResultBuf}

  cNrOfDepVarOptions = 1 + 2 * cMaxClaim;
  {-Min. nr. of columns in OutputProcMatrix (zie 'UDSmodel')}

  cEP0   = 0;        {-EP-Array-index used for all TDSmodel's}
  cEP1   = 1;        {-EP-Array-index used for testing TDSmodel's}

  cmpAlgRout    = 1; {-Mapping van EP[ cEP0 ]}
  cmpStepRout   = 2;
  cmpDCRoot     = 3;
  cmpDCStepRout = 4;
  cmpDriver     = 5;
  cmp_nsubstep  = 6;
  cmp_nstep     = 7;
  cmp_maxstp    = 8;
  cmp_htry      = 9;
  cmp_hmin      = 10;
  cmp_eps       = 11;
  cmpModelID    = 12;
  cmpReadyToRun = 13;
  cmpnRP        = 14;
  cmpnSQ        = 15;
  cmpnRQ        = 16;
  cmpArea       = 17;
  cmpCurrent_xs = 18;
  cmpAnalytic_DerivsProc = 19;
  cmpnDc        = 20;

  {-Fout-codes}
  cErrFileWithTableUpdateInfoDoesNotExist = -150;
  cErrorInitialisingUpdateTable = -151;
  cErrNoValidSectionsInUpdateEPfile = -152;
  cErrInvalidKeyNameInUpdateEPfile = -153;
  cErrorRestoringTable = -154;

implementation
const        {-T.b.v. 'Update' en 'Restore'}
  xInDepStr  = 'xInDep';
  xDepStr    = 'xDep';
  TableStr   = 'Table';
  DefaultStr = 'NoChange';

Function DxTilNextYChange( const x: Double; const Direction: TDirection;
                           EP: TExtParArray ): Double;
var
  i, n: Integer;
begin
  n := Length( EP );
  if ( Direction = FrWrd ) then begin
    Result := MaxDouble;
    for i:=0 to n-1 do
      Result := Min( Result, EP[ i ].DxTilNextYChange( x, Direction ) );
  end else begin
    Result := -MaxDouble;
    for i:=0 to n-1 do
      Result := Max( Result, EP[ i ].DxTilNextYChange( x, Direction ) );
  end;
end;

Function TExtPar.HasData: Boolean;
begin
  Result := ( (xDep.count>0) or (xInDep.count>0) );
end;

Constructor TExtPar.Create;
begin
  Inherited Create;
  Try
    xDep   := TxyTableList.Create;
    xInDep := TDoubleMatrixList.Create;
  Except
    On E: Exception do begin
      MessageDlg( 'Initialisation failed in: ' + '"TExtPar.Create".', mtError, [mbOk], 0);
    end;
  end;
end;

Destructor TExtPar.Destroy;
begin
  xDep.Free;    xDep := nil;
  xInDep.Free;  xInDep := nil;
  Inherited Destroy;
end;

Function TExtPar.ReadxDepFromTextFile( var f: TextFile ): Integer;
begin
  Result := xDep.ReadXYTablesFromTextFile( f );
end;

Function TExtPar.ReadxInDepFromTextFile( var f: TextFile ): Integer;
begin
  Result := xInDep.ReadDoubleMatrixListFromTextFile( f );
end;

Function TExtPar.DxTilNextYChange( const x: Double;
         const Direction: TDirection ): Double;
begin
  Result := xDep.DxTilNextYChange( x, Direction );
end;

Function TExtPar.Clone: TExtPar;
begin
  Result        := TExtPar.Create;
  Result.xDep   := xDep.Clone;
  Result.xInDep := xInDep.Clone;
end;

Procedure TExtPar.ReadFromTextFile( var f: TextFile );
begin
  ReadxInDepFromTextFile( f );
  ReadxDepFromTextFile( f );
end;

Procedure TExtPar.WriteToTextFile( var f: TextFile );
begin
  xInDep.WriteToTextFile( f );
  xDep.WriteToTextFile( f );
end;

Function TExtPar.SaveToStream( SaveStream: TStream ): Boolean;
begin
  Result := xInDep.SaveToStream( SaveStream ) and
            xDep.SaveToStream( SaveStream );
end;

Function  TExtPar.LoadFromStream( LoadStream: TStream ): Boolean;
begin
  Result := xInDep.LoadFromStream( LoadStream ) and
            xDep.LoadFromStream( LoadStream );
end;

Function TExtPar.Update( var fIniFile: TiniFile; var ExtParBuf: TExtPar;
         var UpdateCount, IErr: Integer ): Boolean;
var
  i, iTableType, NrxDepKeys, NrxInDepKeys: Integer;
  SectionStr, IdentStr, TableFileName: String;
  f: TextFile;
{Voorbeeld ini-file (dsmodelXXX.up1):
[xInDep]
Table0 = xInDep101_0.tb1
[xDep]
Table3 = xDep101_3.tb1
}
Function Check_fIniFile( var IErr: Integer ): Boolean;
var
  SL: TStringList;
begin
  WriteToLogFile( 'Check fIniFile.' );

  {$ifdef testUpdate}
  MessageDlg('Check_fIniFile', mtInformation, [mbOK], 0);
  {$endif}

  Result := False; IErr := cUnknownError;

  {-Controleer of de juiste Sections aanwezig zijn: (xDep en/of xInDep)}
  SectionStr := xDepStr;
  SL         := TStringList.Create;
  fIniFile.ReadSection( SectionStr, SL );
  NrxDepKeys := SL.Count;
  WriteToLogFile( IntToStr( NrxDepKeys ) + ' Key(s) read from section: ' + SectionStr );
  SL.Free;

 {$ifdef testUpdate}
  MessageDlg(IntToStr( NrxDepKeys ) + ' Key(s) read from section: ' + SectionStr, mtInformation, [mbOK], 0);
  {$endif}

  SectionStr := xInDepStr;
  SL         := TStringList.Create;
  fIniFile.ReadSection( SectionStr, SL );
  NrxInDepKeys := Sl.Count;
  WriteToLogFile( IntToStr( NrxInDepKeys ) + ' Key(s) read from section: ' + SectionStr );
  Sl.Free;

 {$ifdef testUpdate}
  MessageDlg(IntToStr( NrxInDepKeys ) + ' Key(s) read from section: ' + SectionStr, mtInformation, [mbOK], 0);
 {$endif}

  if ( ( NrxDepKeys + NrxInDepKeys ) = 0 ) then begin
    IErr := cErrNoValidSectionsInUpdateEPfile; Exit;
  end else begin
    Result := True; IErr := cNoError;
  end;

end; {-Function Check_fIniFile}

begin
  Result := False; IErr := cUnknownError; UpdateCount := 0;

  WriteToLogFile( 'Update External Parameter.' );

  if not Check_fIniFile( IErr ) then Exit;
  
  {$ifdef testUpdate}
  MessageDlg('Check_fIniFile=True', mtInformation, [mbOK], 0);
  {$endif}

  {-Update info van 'xDep' tabellen}
  SectionStr := xDepStr;
  WriteToLogFile( 'Handle "' + SectionStr + '" section.' );

  {$ifdef testUpdate}
  MessageDlg('Handle "' + SectionStr + '" section.', mtInformation, [mbOK], 0);
  {$endif}

  with xDep do begin
    for i:=0 to LastIndex do begin
      IdentStr      := TableStr + IntToStr( i );
      TableFileName := fIniFile.ReadString( SectionStr, IdentStr, DefaultStr );
      if ( TableFileName <> DefaultStr ) then begin {-Update}
        TableFileName := ExpandFileName( TableFileName );
        if ( not FileExists( TableFileName ) ) then begin
          IErr := cErrFileWithTableUpdateInfoDoesNotExist;
          WriteToLogFile( 'Unable to locate file: "' + TableFileName + '".' );
          Exit;
        end;
        {-Save table that is about to be replaced in 'ExtParBuf'}

        {$ifdef testUpdate}
        MessageDlg('ExtParBuf.xDep.Add( Items[ '+ IntToStr( i ) + ' ]', mtInformation, [mbOK], 0);
        {$endif}

        Case Items[ i ].DescendantType of
          cTxyTable: begin
            WriteToLogFile( 'Cloning TxyTable.' );
            ExtParBuf.xDep.Add( Items[ i ].Clone( NIL ) );
            end;
          cTxyTableLinInt: begin
            WriteToLogFile( 'Cloning TxyTableLinInt.' );
            ExtParBuf.xDep.Add( TxyTableLinInt( Items[ i ] ).Clone( NIL ) );
            end;
          else begin
            WriteToLogFileFmt( 'Unknown xDep-table type: %d.', [Ord( Items[ i ].DescendantType )] );
            IErr := cErrorInitialisingUpdateTable; Exit;
          end;
        end; {-case}

        {-Try to initialise a TxyTable (or descendant) and replace existing
          table on 'xDep' with the new table}

        {$ifdef testUpdate}
        MessageDlg('Initialise a TxyTable', mtInformation, [mbOK], 0);
        {$endif}
        
        try
          AssignFile( f, TableFileName ); Reset( f );
          Readln( f, iTableType );
          case iTableType of
            Ord( cTxyTable ): begin
              WriteToLogFile( 'Reading update TxyTable.' );
              Items[ i ] := TxyTable.InitialiseFromTextFile( f, nil );
            end;
            Ord( cTxyTableLinInt ): begin
              WriteToLogFile( 'Reading update TxyTableLinInt.' );
              Items[ i ] := TxyTableLinInt.InitialiseFromTextFile( f, nil );
            end;
          else
            WriteToLogFileFmt( 'Unknown table type: %d in file: "%s".',
              [iTableType, TableFileName] );
            IErr := cErrorInitialisingUpdateTable; Exit;
          end; {-case}
          Inc( UpdateCount );
          CloseFile( f );
        except
          IErr := cErrorInitialisingUpdateTable;
          WriteToLogFile( 'Unable to initialse table TxyTable (or descendant) from file: "'
                   + TableFileName + '".' );
          Exit;
        end; {-Try}
      end; {-if ( TableFileName <> DefaultStr )}
    end; {-for i:=0 to LastIndex}
  end; {-with xDep}

  {-Update info van 'xInDep' tabellen}
  SectionStr := xInDepStr;
  WriteToLogFile( 'Handle "' + SectionStr + '" section.' );

  {$ifdef testUpdate}
  MessageDlg('Handle "' + SectionStr + '" section.', mtInformation, [mbOK], 0);
  {$endif}

  with xInDep do begin
    for i:=0 to LastIndex do begin
      IdentStr      := TableStr + IntToStr( i );
      TableFileName := fIniFile.ReadString( SectionStr, IdentStr, DefaultStr );
      if ( TableFileName <> DefaultStr ) then begin {-Update}
        TableFileName := ExpandFileName( TableFileName );
        if ( not FileExists( TableFileName ) ) then begin
          IErr := cErrFileWithTableUpdateInfoDoesNotExist;
          WriteToLogFile( 'Unable to locate file: "' + TableFileName + '".' );
          Exit;
        end;
        {-Save table that is about to be replaced in 'ExtParBuf'}

        {$ifdef testUpdate}
        MessageDlg('ExtParBuf.xInDep.Add( Items[ '+ IntToStr( i ) + ' ]', mtInformation, [mbOK], 0);
        {$endif}

        Case Items[ i ].DescendantType of
          cDoubleArray: begin
            WriteToLogFile( 'Cloning TDoubleMatrix.' );
            ExtParBuf.xInDep.Add( Items[ i ].Clone );
            end;
          cDbleMtrxColindx: begin
            WriteToLogFile( 'Cloning TDbleMtrxColIndx.' );
            ExtParBuf.xInDep.Add( TDbleMtrxColIndx( Items[ i ] ).Clone );
            end;
          cDbleMtrxColAndRowIndx: begin
            WriteToLogFile( 'Cloning TDbleMtrxColAndRowIndx.' );
            ExtParBuf.xInDep.Add( TDbleMtrxColAndRowIndx( Items[ i ] ).Clone );
            end;
          else begin
            WriteToLogFileFmt( 'Unknown xInDep-table type: %d.', [Ord( Items[ i ].DescendantType )] );
            IErr := cErrorInitialisingUpdateTable; Exit;
          end;
        end; {-case}
        {-Try to initialise a TDoubleMatrix (or descendant) and replace existing
          table on 'xInDep' with the new table}

        {$ifdef testUpdate}
        MessageDlg('Initialise a TDoubleMatrix ', mtInformation, [mbOK], 0);
        {$endif}

        try
          AssignFile( f, TableFileName ); Reset( f );
          Readln( f, iTableType );
          case iTableType of {-Zie corresponderende code in 'UDoubleMatrixList'}
            Ord( cDoubleArray ): begin
              WriteToLogFile( 'Reading update TDoubleMatrix.' );
              Items[ i ] := TDoubleMatrix.InitialiseFromTextFile( f, nil );
              end;
            Ord( cDbleMtrxColindx ): begin
              WriteToLogFile( 'Reading update TDbleMtrxColIndx.' );
              Items[ i ] := TDbleMtrxColindx.InitialiseFromTextFile( f, nil );
              end;
            Ord( cDbleMtrxColAndRowIndx ): begin
	      WriteToLogFile( 'Reading update TDbleMtrxColAndRowIndx.' );
	      Items[ i ] := TDbleMtrxColAndRowIndx.InitialiseFromTextFile( f, nil );
              end;
          else
            WriteToLogFileFmt( 'Unknown table type: %d in file: "%s".',
              [iTableType, TableFileName] );
            IErr := cErrorInitialisingUpdateTable; Exit;
          end; {-case}
          Inc( UpdateCount );
          CloseFile( f );
        except
          IErr := cErrorInitialisingUpdateTable;
          WriteToLogFile( 'Unable to initialse table TxyTable (or descendant) from file: "'
                   + TableFileName + '".' );
          Exit;
        end; {-Try}
      end; {-if ( TableFileName <> DefaultStr )}
    end; {-for i:=0 to LastIndex}
  end; {-with xInDep}

  {$ifdef testUpdate}
  MessageDlg('UpdateCount= ' + IntToStr( UpdateCount ), mtInformation, [mbOK], 0);
  {$endif}

  if ( ( NrxDepKeys + NrxInDepKeys ) <> UpDateCount ) then begin
    IErr := cErrInvalidKeyNameInUpdateEPfile; Exit;
  end else begin
    WriteToLogFile( IntToStr( UpdateCount ) +
    ' tables of external parameter updated.' );
  end;

  Result := True; IErr := cNoError;
end; {-TExtPar.Update}

Function TExtPar.Restore( var fIniFile: TiniFile; var ExtParBuf: TExtPar;
         var RestoreCount, IErr: Integer ): Boolean;
var
  SectionStr, IdentStr, TableFileName: String;
  k, i, iDescendantType: Integer;
begin
  Result       := False;
  IErr         := cUnknownError;
  RestoreCount := 0;

  WriteToLogFile( 'Restore External Parameter.' );

  {-Restore info van 'xDep' tabellen als er wat in de buffer 'ExtParBuf' zit}
  if ( ExtParBuf.xDep.Count > 0 ) then begin
    SectionStr := xDepStr;
    k          := 0;
    WriteToLogFile( 'Handle "' + SectionStr + '" section.' );
    with xDep do begin
      for i:=0 to LastIndex do begin
        IdentStr      := TableStr + IntToStr( i );
        TableFileName := fIniFile.ReadString( SectionStr, IdentStr, DefaultStr );
        if ( TableFileName <> DefaultStr ) then begin {-Restore}
          Case ExtParBuf.xDep.Items[ k ].DescendantType of
            cTxyTable: begin
              WriteToLogFile( 'Restore TxyTable.' );
              Items[ i ] := ExtParBuf.xDep.Items[ k ].Clone( NIL );
              end;
            cTxyTableLinInt: begin
              WriteToLogFile( 'Restore TxyTableLinInt.' );
              Items[ i ] := TxyTableLinInt( ExtParBuf.xDep.Items[ k ] ).Clone( NIL );
              end;
            else begin
              iDescendantType := Ord( ExtParBuf.xDep.Items[ k ].DescendantType );
              WriteToLogFileFmt( 'Unknown xDep-table type: %d.', [iDescendantType] );
              IErr := cErrorRestoringTable; Exit;
            end;
          end; {-case}
          Inc( k );
        end; {-if ( TableFileName <> DefaultStr )}
      end; {-for i:=0 to LastIndex}
    end; {-with xDep}
    RestoreCount := k;
  end; {-if ( ExtParBuf.xDep.Count > 0 )}

  {-Restore info van 'xInDep' tabellen als er wat in de buffer 'ExtParBuf' zit}
  if ( ExtParBuf.xInDep.Count > 0 ) then begin
    SectionStr := xInDepStr;
    k          := 0;
    WriteToLogFile( 'Handle "' + SectionStr + '" section.' );
    with xInDep do begin
      for i:=0 to LastIndex do begin
        IdentStr      := TableStr + IntToStr( i );
        TableFileName := fIniFile.ReadString( SectionStr, IdentStr, DefaultStr );
        if ( TableFileName <> DefaultStr ) then begin {-Restore}
          Case ExtParBuf.xInDep.Items[ k ].DescendantType of
            cDoubleArray: begin
              WriteToLogFile( 'Restore TDoubleArray.' );
              Items[ i ] := ExtParBuf.xInDep.Items[ k ].Clone;
              end;
            cDbleMtrxColindx: begin
              WriteToLogFile( 'Restore TDbleMtrxColindx.' );
              Items[ i ] := TDbleMtrxColindx( ExtParBuf.xInDep.Items[ k ] ).Clone;
              end;
            cDbleMtrxColAndRowIndx: begin
              WriteToLogFile( 'Restore TDbleMtrxColAndRowIndx.' );
              Items[ i ] := TDbleMtrxColAndRowIndx( ExtParBuf.xInDep.Items[ k ] ).Clone;
              end;
            else begin
              iDescendantType := Ord( ExtParBuf.xInDep.Items[ k ].DescendantType );
              WriteToLogFileFmt( 'Unknown xInDep-table type: %d.', [iDescendantType] );
              IErr := cErrorRestoringTable; Exit;
            end;
          end; {-case}
          Inc( k );
        end; {-if ( TableFileName <> DefaultStr )}
      end; {-for i:=0 to LastIndex}
    end; {-with xInDep}
    RestoreCount := RestoreCount + k;
  end; {-if ( ExtParBuf.xInDep.Count > 0 )}

  WriteToLogFile( IntToStr( RestoreCount ) +
    ' External parameter tables restored.' );

  Result := True; IErr := cNoError;
end; {-Function TExtPar.Restore}

Function GetNrOfDepVariables( const EP: TExtParArray ): Integer;
begin
  Result := EP[ cEP0 ].xInDep.Items[ 1 ].GetNRows;
end;

end.



