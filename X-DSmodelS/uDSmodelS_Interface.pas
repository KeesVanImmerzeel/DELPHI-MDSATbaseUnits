unit uDSmodelS_Interface;
  {-Routines die het makkelijker maken om een MD-SAT model te koppelen aan een
    programma en hiermee een stationaire run te doen }
interface

uses
  Windows, System.SysUtils, System.Classes, uProgramSettings, uError, uAlgRout,
  uDSmodelS, LargeArrays, math, Dialogs;

Type
  {PDSmodelS_Interface = ^TDSmodelS_Interface;}
  TDSmodelS_Interface = Class( TObject )
  private
    {-Parameters for interface with 'DSlink'}
    Settings_Array,      {-Model Settings in format of TDSDriver Procedure (ref. 'UdsModelS' and 'DSmodfor')}
    RP_array, SQ_array, RQ_array, vResult_Array,
    tTS_Array, vTS_Array, tResult_Array: TArrayOfDouble;
      {-Stationary versions of interface arrays (internal format)}
      {-Memory for these arrays is allocated by a call to "Load_Model"}
    Settings, tTS, vTS, tResult, vResult: ^Real;  {-Pointer to the first element of arrays}
  public
     Hnd_to_DSmodfor: THandle;   {-Handle to 'DSmodfor.dll'}
     DSdriver: TDSDriver; {-Handle to DSDriverRoutine in 'DSmodfor.dll' }
     nRP, nSQ, nRQ, nResPar: Integer; {-Values set by function "Load_Model"}
//   nRP,        {-Aant. vlak-tijdreeksen die het model verwacht van de schil}
//   nSQ,        {-Aant. punt-tijdreeksen die het model verwacht van de schil}
//   nRQ,        {-Aant. lijn-tijdreeksen die het model verwacht van de schil}
//   nResPar,    {-Aant. Aantal uitvoer-tijdreeksen}
     Constructor Create( const ModelID: Integer; var IResult: Integer );
     Procedure Run_Model( const RP, SQ, RQ: TarrayOfDouble; var Result_Array: TarrayOfDouble; var IResult: Integer); Virtual;
       {-Maak een stationaire run}
     Destructor Destroy; Override;
       {-Do not call Destroy directly. Call Free instead.
       Free verifies that the object reference is not nil before calling Destroy.
       Call the inherited Destroy as the last statement in the overriding method.}
  End;

var
  DSmodelS_Interface: TDSmodelS_Interface;

implementation

Constructor TDSmodelS_Interface.Create( const ModelID: Integer; var IResult: Integer );
  {-Load 'Model' via DSmodfor.dll. IResult = cNoError if succes}

var
  DSmodfor_FileName: String;
  Length_tTS_Array, Length_tResult_Array,
  i, j: Integer;
const
  cNrOfOutputTimes = 1; {-Output times in case of stationaire run}
begin
  inherited Create;
  Try
    Try
      Writeln( lf, 'Try to initialise model: ', ModelID );

      IResult := cUnknownError;

      {-Create handle to 'DSmodfor.dll'}
      DSmodfor_FileName := AlgRootDir + 'DSmodfor.dll';
      Hnd_to_DSmodfor := LoadLibrary( PChar( DSmodfor_FileName ) );
      if ( Hnd_to_DSmodfor = 0 ) then begin
        IResult := cCannotCreateHandleTo_DSmodfor_DLL;
        Raise ECannotCreateHandleTo_DSmodfor_DLL.CreateResFmt(
          @sCannotCreateHandleTo_DSmodfor_DLL, [ExpandFileName( DSmodfor_FileName )] );
      end;
      {-Create Handle to DSDriver Routine in 'DSmodfor.dll' }
      @DSdriver := GetProcAddress( Hnd_to_DSmodfor, PChar( 'DSDriver'  ) );
      if ( @DSdriver = nil ) then begin
        IResult := cCannotCreateHandleToDSDriver;
        Raise ECannotCreateHandleToDSDriver.CreateResFmt(
          @sCannotCreateHandleToDSDriver, ['DSDriver'] );
      end;

      {-Initialise Model}

      {-Step 1: Prepare the Settings_Array to make a request to initialise the model}
      SetLength( Settings_Array, c_Length_Of_Settings_Array );
      for i:=0 to Length( Settings_Array )-1 do
        Settings_Array[ i ] := 0;
      Settings_Array[c_ModelID]      := ModelID;  {-Modelnr. dat de schil wil initialiseren (input)}
      //  c_nRP         = 1;  {-Aantal RP-tijdreeksen dat het model van de schil verwacht(output)}
      //  c_nSQ         = 2;  {-Aantal punt-tijdreeksen dat het model van de schil verwacht(output)}
      //  c_nRQ         = 3;  {-Aantal lijn-tijdreeksen dat het model van de schil verwacht(output)}
      //  c_nResPar     = 4;  {-Aantal result-tijdreeksen waarmee wordt gerekend; wordt bepaald door boot-procedure in dsmodel*.dll (output)}
      Settings_Array[c_Request]  := cRQInitialise;  {-Type opdracht dat de schil wil uitvoeren (input, zie hieronder)}
      //  c_MaxStp       = 6;  {-Max. aantal stappen voor integratie (input) HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het bestand *.EP0 wordt gebruikt}
      //  c_Htry         = 7;  {-Initiele stapgrootte [tijd](input) HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het bestand *.EP0 wordt gebruikt}
      //  c_Hmin         = 8;  {-Minimale stapgrootte [tijd](input) HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het bestand *.EP0 wordt gebruikt}
      //  c_Eps          = 9;  {-Nauwkeurigheidscriterium(input) HIERMEE WORDT NOG NIKS GEDAAN: de input vanuit het bestand *.EP0 wordt gebruikt}
      Settings_Array[c_Area] := 1.0;
      New(Settings); Settings := @Settings_Array[0];

      {-Step 2: Make request to initalise the model}
      New( tTS ); New( vTS ); New( tResult ); New( vResult );
      Try
        DSDriver( Settings^, tTS^, vTS^, tResult^, vResult^ ); {-Initialise model 113}
      Except
        IResult := cRequestToInitialiseModelFailed;
        Raise ERequestToInitialiseModelFailed.CreateResFmt(
          @sRequestToInitialiseModelFailed, [ModelID] );
      End;
      IResult := Trunc( vResult^ );
      if ( IResult <> cNoError ) then begin
        Raise ERequestToInitialiseResultedInError.CreateResFmt(
          @sRequestToInitialiseModelFailed, [IResult] );
      end;
      {-Show values of resulting Settings_Array in log file (optional)}
      Writeln( lf, 'Settings_Array of model: ', ModelID );
      for i:=0 to c_Length_Of_Settings_Array-1 do begin
        writeln( lf, i, ' ', Settings_Array[ i ]:10:2 );
      end;
      {-Copy values info about length of in- and output arrays to variables nRP, nSQ etc.}
      Writeln( lf, 'Length of in- and output arrays:' );
      nRP := max( trunc( Settings_Array[ c_nRP ] ), 0 );     Writeln( lf, 'nRP= ', nRP );
      nSQ := max( trunc( Settings_Array[ c_nSQ ] ), 0 );     Writeln( lf, 'nSQ= ', nSQ );
      nRQ := max( trunc( Settings_Array[ c_nRQ ] ), 0 );     Writeln( lf, 'nRQ= ', nRQ );
      nResPar := max( trunc( Settings_Array[ c_nResPar ] ), 0 ); Writeln( lf, 'nResPar= ', nResPar );

      {-Allocate memory for input arrays}
      SetLength( RP_array, nRP );
      SetLength( SQ_array, nSQ );
      SetLength( RQ_array, nRQ );
      {-vResult_Array wordt hieronder geinitialiseerd );

      {-Allocate memory for arrays that are used internally}
      {-tTS_Array and vTS_Array}
      Length_tTS_Array := nRP*2 + nSQ*2 + nRQ*2; {= Aantal invoertijdstippen bij stationaire run plus 1}
      SetLength( tTS_Array, Length_tTS_Array ); {-Allocate memory for output array}
      for i := 0 to ( Length_tTS_Array div 2 ) - 1 do begin
        tTS_Array[ 2*i ]   := 1; {-Aantal tijdstippen}
        tTS_Array[ 2*i+1 ] := 0; {-Tijdstip}
      end;
      SetLength( vTS_Array, Length_tTS_Array ); {-Values are supplied by a call to "Run_Model"}
      {-tResult_Array and vResult_Array}
      Length_tResult_Array := 1 + nResPar*cNrOfOutputTimes;
      SetLength( tResult_Array, Length_tResult_Array );
      SetLength( vResult_Array, Length_tResult_Array );
      tResult_Array[ 0 ] := cNrOfOutputTimes;
      vResult_Array[ 0 ] := cNoError;
      for i := 1 to nResPar do begin
        for j:= 1 to cNrOfOutputTimes do begin
          tResult_Array[ (i-1)*cNrOfOutputTimes + j ] := 0; {-Stationary run}
          vResult_Array[ (i-1)*cNrOfOutputTimes + j ] := 0; {-Default result value}
        end;
      end;

      {-Set pointers to arrays that are used internally}
      tTS     := @tTS_Array[0];
      vTS     := @vTS_Array[0];
      tResult := @tResult_Array[0];
      vResult := @vResult_Array[0];

      Writeln( lf, Format( 'Model %d is initialised.', [ModelID] ) );
    Except
      On E: Exception do begin
        HandleError( E.Message, true );
      end;
    End;
  Finally
  End;

end;

Procedure TDSmodelS_Interface.Run_Model( const RP, SQ, RQ: TarrayOfDouble;
  var Result_Array: TarrayOfDouble; var IResult: Integer);
  {IResult = cNoError if succes}
var
  i, j: Integer;
begin
  IResult := cUnknownError;
  Try
    {-Copy values from shell to internally used arrays}
    j := 0;
    for i := 0 to nRP-1 do begin
      vTS_Array[ j ]   := RP[ i ]; {-Initiele waarde (tot t=0)}
      vTS_Array[ j+1 ] := RP[ i ]; {-Waarde vanaf t=0}
      Inc( j, 2 );
    end;
    for i := 0 to nSQ-1 do begin
      vTS_Array[ j ]   := SQ[ i ];
      vTS_Array[ j+1 ] := SQ[ i ];
      Inc( j, 2 );
    end;
    for i := 0 to nRQ-1 do begin
      vTS_Array[ j ]   := RQ[ i ];
      vTS_Array[ j+1 ] := RQ[ i ];
      Inc( j, 2 );
    end;

    Settings_Array[c_Request]  := cRQRun;

    DSDriver( Settings^, tTS^, vTS^, tResult^, vResult^ );

    IResult := Trunc( vResult_Array[0] );

    for i:=1 to Length( vResult_Array ) - 1 do
      Result_Array[ i-1 ] := vResult_Array[ i ];

  Except
    On E: Exception do begin
      HandleError( sCallToDSDriverRoutineResultedInCriticalError, true );
    end;
  End;

end;

Destructor TDSmodelS_Interface.Destroy;
begin
  Try
//    Try
//      Settings_Array[c_Request]  := cRQRFinalise;
//      ShowMessage( 'Calling DSDriver with cRQRFinalise request...' );
//      DSDriver( Settings^, tTS^, vTS^, tResult^, vResult^ );
//      ShowMessage( 'cRQRFinalise request finished.' );
//    Except
//    End;
//    ShowMessage( 'FreeLibrary DSModelS...' );
// Opm.: de COMBINATIE cRQRFinalise en FreeLibrary levert een critical error op... (onbegrepen).

    Try FreeLibrary( Hnd_to_DSmodfor ); except end; {-dan maar alleen freelibrary...}

//    ShowMessage( 'Library SModelS is free.' );
  Finally
    SetLength( RP_array, 0 );
    SetLength( SQ_array, 0 );
    SetLength( RQ_array, 0 );
    SetLength( Settings_Array, 0);
    SetLength( tTS_Array, 0 );
    SetLength( vTS_Array, 0 );
    SetLength( tResult_Array, 0 );
    SetLength( vResult_Array, 0 );
    Inherited Destroy;
  End;
end;

end.
