unit UDSmodel;
  {-Base class for Dynamic Simulation Models}

interface

{.$define test}
{.$define test2}
{.$define test3}   {Toont steeds de integratiestap en stapgrootte (x1,x2,dx)}

uses
  SysUtils, Windows, LargeArrays, ExtParU, UdcFunc, USpeedProc, uINTodeCLASS, Math,
  uError, xyTable, uAlgRout, forms, Dialogs, IniFiles, System.UITypes, Vcl.ComCtrls,
  Classes, Zlib, DUtils;

type
  TDSmodel = Class( TINTode )
    private
      DLLdsModel: THandle; {-Handle of DLL that contains DerivsProc and
                             FnBootEP}
      Procedure Copy_OutputProcMatrix_Values_To_Ystart;
      Procedure Integrate( x1, x2: Double; var IErr: Integer ); Reintroduce;
        {-Used by 'Run' procedure. Integrate DerivsProc from x1 to x2 if the
          model is ReadyToRun. The result is stored in ystart. Sets dydx at x2.
          If x1=x2, no integration is performed and only dydx is set at x1}
      Function Claim( const i: Integer ): Integer;
        {-Nr. of columns claimed in Resultbuf by dep. variable i}
     protected
      DerivsProc: TDerivs;     {-Loaded from DLLdsModel}
    public
      EP: TExtParArray;        {-External parameter-array}
      FnBootEP: TBootEPArray;  {-Loaded from DLLdsModel}
      ystart,                  {-Dependent variable vector}
      dydx: TLargeRealArray;   {-Derivative vector (=momentane snelheid)}
      Function ModelID: Word; Virtual;
        {-Unique identification number for the model}
      Function NResPar: Integer; Virtual;
      {-Number of Result-parameters = the sum of all columns claimed by the
        OutputProcMatrix in ResultBuf minus one. Values in OutputProcMatrix
        (=EP[0].xIndep.Items[1]) must be set by boot-procedure. NResPar must be
        >0 to be able to excecute 'run' sucessfully}
      Constructor Create( const DLLFileName: String; const ModelIndx,
                          BootVariantIndx: Word; var IErr: Integer ); Reintroduce;
      {-Load speed-procedure (=DerivsProc) from DLL-file. Initialise:
        - EP (= TExtParArray, lengte cLengthTExtParArray)
        - ystart (=0, en NIET de waarde in de OutputProcMatrix)
        - dydx (=0).
        De tabellen 1 en 2 van EP (=EP[ 0 ].xInDep.Items[ 0&1 ]) moeten
        via de TBootEPArray-functie worden ingevuld. De speed-procedure en de
        TBootEPArray-functie(s) moeten beschikbaar zijn in het DLL-bestand.
        De eerste tabel bevat gegevens die nodig zijn om de base-class (TINTode)
        te initialiseren.
        De tweede tabel (=OutputProcMatrix (=EP[0].xIndep.Items[1])) bevat begin-
        waarden (ystart) voor de 'run' procedure en de settings die nodig zijn
        voor het selecteren en verwerken van de berekeningsresulaten voordat ze
        in ResultBuf worden gezet door 'Run'.
        ModelIndx       = index van het model in de DLL-file;
        BootVariantIndx = index van de TBootEPArray-functie in de DLL-file.
        De DLL kan dus evt. meerdere TBootEPArray-functies bevatten.
        Als de TBootEPArray-functie ALLE benodigde modelinvoer in de EP-array
        zet, dan is het model klaar voor gebruik. De boot-procedure kan aan
        het model doorgeven dat het klaar is voor gebruik door de procedure
        'SetReadyToRun' aan te roepen }
      Procedure Run( var ResultBuf: TDoubleMatrix; var IErr: Integer ); Virtual;
        {-Major procedure of this class: fills ResultBuf with output for all
          output-times specified. ResultBuf moet reeds zijn geinitialiseerd in
          het juiste formaat voordat deze procedure wordt aangeroepen:
          NRows=NrOfOutputTimes; NCols=NResPar+1.
          Kolom 1: uitvoertijden; Kolommen 2..NResPar+1: berekeningsresul-
          taten v.d. uitvoervariabelen 1..NResPar}
      Function ReadyToRun: Boolean; Virtual;
        {-True if all data is loaded to run the model. This flag must be set in
          EP[ 0 ] by the bootprocedure (ref. Procedure 'SetReadyToRun'). Deze
          functie controleert NIET of ResultBuf is geinitialiseerd in overeen-
          stemming met NResPar}
      Procedure SetReadyToRun( const Value: Boolean ); Virtual;
        {-Set value of ReadyToRun-flag on EP[0]}
      Function NrOfDepVar: Integer; Virtual;
        {-Length of dependent variable vector ystart}
      Function NrOfOutputTimes: Integer; Virtual;
        {-Nr. of Output times for Run-procedure. Kan alleen <> 0 zijn als
          ReadyToRun=true}
      Function Transient: Boolean; Virtual;
        {-True if model is ready for a transient-run. Kan alleen 'true' zijn als
          ReadyToRun=true}
      Function OutputTime( const i: Integer ): Double; Virtual;
        {-Equal to the i-th output-time if ReadyToRun=true; 0 otherwise}
      Function PrepareYstartForRun( var IErr: Integer ): Boolean; Virtual;
        {-Zet start-waarden in Ystart. Hierin wordt de proce-
          dure 'Copy_OutputProcMatrix_Values_To_Ystart' aangeroepen en wordt
          de DerivsProc een keer aangeroepen waarbij 'Context' heel even de
          waarde 'UpdateYstart' heeft. (deze functie maakt deel uit van de zgn.
          'Run fase-1'}
      Destructor Destroy; Override;
  end;

Function DefaultBootEPFromTextFile(
  const EpDir: String;   {-Directory waar Ep-bestanden moeten worden gezocht}
  const BootEpArrayOption: TBootEpArrayOption;
  const
  ModelID,               {-ID van model: DLL-gebonden informatie}
  NrOfDepVar,            {-Length of dependent variable vector ystart; idem}
  nDC,                   {-Aantal keren dat een discontinuiteitsfunctie wordt
                           aangeroepen in de procedure met snelheidsvergelij-
                           kingen (DerivsProc)}
  NrXIndepTbls,          {-Aantal tijdsonafhankelijke tabellen op EP[0]; idem}
  NrXDepTbls: Integer;   {-Aantal tijdsafhankelijke tabellen op EP[0]; idem}
  var Indx: Integer;     {-Kan door DerivsProc worden gebruikt om info op
                           EP-array te vinden. In dit geval Indx=1}
  var EP: TExtParArray   {-External parameter-array}
  ): Integer;
{-Loads basic data on EP[ cEP0 ] for any TDSmodel. This general
  procedure does NOT make a call to 'SetReadyToRun': the model may need more
  data. Result := cNoError if data is loaded succesfully}

Function DefaultTestBootEPFromTextFile( const EpDir: String;
  const BootEpArrayOption: TBootEpArrayOption; const ModelID, NrXDepTbls: Integer;
  var Indx: Integer; var EP: TExtParArray ): Integer;
{-Default Boot-procedure loads data in EP[ cEP1 ].
  The first table in xInDep.Items must contain at least 1 output-time.
  This general procedure does NOT make a call to 'SetReadyToRun': the model may
  need more data.
  Deze procedure bevat geen NrXInDepTbls-parameter omdat dit zou leiden tot
  slecht code in de DerivsProc}

Procedure SetReadyToRun( var EP: TExtParArray );
{-Set Ready-to-run flag on EP[0] to 'cReadyToRun'. This procedure
  may be used by boot-procedures}

const
  cDSbootFileName = 'Boot';
  cDSmodelFileName = 'DSmodel';
  cDSOutputFileNameExt = '.out';

  cLengthTExtParArray         = 10;

  cNr_TINTode_Create_Settings = 20;

  cBoot0 = cEP0 + 1; {-Verander dit niet!}
  cBoot1 = cEP1 + 1; {-Verander dit niet!}

  cResultUndefined = -999;

Const
    {-Error codes: -899...-800}
  cUnableToLoadSpeedDLL = -899;
  cUnableToLocateSpeedProc = -898;
  cFailToBootEPArray = -897;
  cUnableToLocateFnBootEP = -896;
  cBootEPArrayVariantIndexUnknown = -895;
  cErrorExtractingTINTode_Create_Settings = -894;
  cErrorCreatingYstartAndDyDxArrays = -893;
  cModelIsNotReadyToRun = -892;
  cNegativeMassInConcCalculation = -891;
  cNegativeInfiltrInConcCalculation = -890;
  cInvalidProcType = -889;
  cErrorCreatingYstart_at_x1 = -887;
  cNegativeTimeIntervalSpecified = -886;
  cNotEnoughXIndepTblsInEP0 = -885;
  cInvalidNr_TINTode_Create_Settings = -884;
  cDimensionsOfDepVarTableInvalid = -883;
  cNotEnoughXdepTblsInEP0 = -882;
  cFileFailureInBootingEP0 = -881;
  cNotEnoughXIndepTblsInEP1 = -880;
  cDimensionsOfOutputTimesTableInvalid = -879;
  cNotEnoughXdepTblsInEP1 = -878;
  cFileFailureInBootingEP1 = -877;
  cIntegrationError = -876;
  cNegativeGiftInFractionCalculation = -875;
  cUnableToCreateBootLogFile = -874;
  cBootFileDoesNotExist = -873;
  cErrUpdatingEP = -872;
  cErrNoUpdateFile = -871;
  cErrorCreatingResultBuf = -870;
  cFailToBootEPArrayFromBIN = -869;

var
  {-Direction is altijd FrWrd bij simulaties (de tijd schrijdt voort...)}
  Direction: TDirection;
  EpDir: String; {-Lokatie van EP-bestanden. Default: AlgRootDir}

implementation
Const
  cDSbootFileNameExt = '.EP0';              cDSbbootFileNameExtBIN = '.BP0';
  cDSTestFileNameExt = '.EP1';              cDSTestFileNameExtBIN = '.BP1';
  cDSbootLogFileNameExt = '.lg0';
  cDSTestBootLogFileNameExt = '.lg1';

  cReadyToRun    = 1;
  cNotReadyToRun = 0;

var
  iCount: Integer; {-Voor test-doeleinden}
  {$ifdef test2}
  test2: Boolean; {-Idem}
  {$endif}

Constructor TDSmodel.Create( const DLLFileName: String; const ModelIndx,
                             BootVariantIndx: Word; var IErr: Integer );
var
  IAlgRout, IStepRout, IDCRoot, IDCStepRout, IDriver: Word;
  i, I_nsubstep, I_nstep, I_maxstp, n: Integer;
  I_htry, I_hmin, I_eps: Double;
begin
  {-Create handle to DLLdsModel}
  {$ifdef test}
  Application.MessageBox( 'Loading Library DerivsProc', 'Info', MB_OKCANCEL );
  {$endif}
  DLLdsModel := LoadLibrary( PChar( DLLFileName ) );
  if DLLdsModel = 0 then begin
    IErr := cUnableToLoadSpeedDLL; Exit;
  end else begin {-Load DerivsProc from DLL}

    {$ifdef test}
    Application.MessageBox( 'Loading DerivsProc', 'Info', MB_OKCANCEL );
    {$endif}

    @DerivsProc := GetProcAddress( DLLdsModel, PChar( ModelIndx ) );
    if ( @DerivsProc = nil ) then begin
      IErr := cUnableToLocateSpeedProc; Exit;
    end else begin
      {-In order to construct base-class (TINTode), it is necessary to
        call the TBootEPArray-function first (=FnBootEP) }
      SetLength( EP, cLengthTExtParArray );
      for i:=0 to cLengthTExtParArray-1 do
        EP[ i ] := TExtPar.Create;

      {$ifdef test}
      ShowMessage( 'Extended parameter array created with ' + IntToStr( cLengthTExtParArray ) + ' elements.' );
      Try
        with EP[ cEP0 ] do begin
        end;
        ShowMessage( 'EP[ cEP0 ] can be used in TDSmodel.Create' );
      Except
        ShowMessage( 'EP[ cEP0 ] can NOT be used in TDSmodel.Create' );
      end;
      Application.MessageBox( 'Loading TBootEPArray-function', 'Info',
                               MB_OKCANCEL );
      ShowMessage( 'BootVariantIndx = ' + IntToStr( BootVariantIndx ) );
      {$endif}

      {-Load TBootEPArray-functie}
      FnBootEP := GetProcAddress( DLLdsModel, PChar( BootVariantIndx ) );
      if ( @FnBootEP = nil ) then begin
        IErr := cUnableToLocateFnBootEP; Exit;
        {$ifdef test}
        Application.MessageBox( 'Could not locate FnBootEP', 'Error',
                                MB_OKCANCEL );
        {$endif}
      end else begin
        {$ifdef test}
        ShowMessage( 'Executing FnBootEP with Ord(cBootEPFromTextFile) = ' + IntToStr( Ord(cBootEPFromTextFile) ) );
        {$endif}
        {-Execute TBootEPArray-functie}
        IErr := FnBootEP( EpDir, cBootEPFromTextFile, EP );
      end;
      if ( IErr <> cNoError ) then exit else begin
        try
          with EP[ cEP0 ].xInDep.Items[ 0 ] do begin
            IAlgRout    := Trunc( GetValue( cmpAlgRout, 1 ) );
            IStepRout   := Trunc( GetValue( cmpStepRout, 1 ) );
            IDCRoot     := Trunc( GetValue( cmpDCRoot, 1 ) );
            IDCStepRout := Trunc( GetValue( cmpDCStepRout, 1 ) );
            IDriver     := Trunc( GetValue( cmpDriver, 1 ) );
            I_nsubstep  := Trunc( GetValue( cmp_nsubstep, 1 ) );
            I_nstep     := Trunc( GetValue( cmp_nstep, 1 ) );
            I_maxstp    := Trunc( GetValue( cmp_maxstp, 1 ) );
            I_htry      :=        GetValue( cmp_htry, 1 );
            I_hmin      :=        GetValue( cmp_hmin, 1 );
            I_eps       :=        GetValue( cmp_eps, 1 );
          end; {with}
          {$ifdef test}
          Application.MessageBox( 'Creating TINTode', 'Info', MB_OKCANCEL );
          {$endif}
          Inherited Create( IAlgRout, IStepRout, IDCRoot, IDCStepRout, IDriver,
                    I_nsubstep, I_nstep, I_maxstp, I_htry, I_hmin, I_eps, IErr );
          if ( IErr <> cNoError ) then exit;
          {$ifdef test}
          Application.MessageBox( 'Creating TINTode DONE', 'Info', MB_OKCANCEL );
          {$endif}
          {Try to load ystart from EP[ cEP0 ].xInDep.Items[ 1 ]}

          n := EP[ cEP0 ].xInDep.Items[ 1 ].GetNRows;
          {-Length of dependent variable vector}
          try
            ystart := TLargeRealArray.Create( n, nil );
            dydx   := TLargeRealArray.CreateF( n, 0, nil );
          except
            IErr := cErrorCreatingYstartAndDyDxArrays; Exit;
          end;
            Copy_OutputProcMatrix_Values_To_Ystart;
        except
        IErr := cErrorExtractingTINTode_Create_Settings; Exit;
        end;
      end; {-( IErr <> cNoError )}

    end; {-if ( @DerivsProc = nil )}
  end; {if ( DLLdsModel = 0 )}
end;

Procedure TDSmodel.Copy_OutputProcMatrix_Values_To_Ystart;
var
  i: Integer;
begin
  for i:=1 to NrOfDepVar do
    ystart[ i ] := EP[ cEP0 ].xInDep.Items[ 1 ].GetValue( i, 1 );
end;

Function TDSmodel.PrepareYstartForRun( var IErr: Integer ): Boolean;
var
  x: Double;
  Context: Tcontext;
  var ModelProfile: PModelProfile;
begin
  Copy_OutputProcMatrix_Values_To_Ystart; {-Values from EP[ cEP0 ] --> ystart[]}
  x := 0; {-Set initial values from shell at t=0}
  Context := UpdateYstart;
  DerivsProc( x, ystart, dydx, EP, Direction, Context, ModelProfile, IErr );
  {-Opm.: nu wijst ModelProfile naar het modelprofiel!}
  Result := ( IErr = cNoError );
end;

Function TDSmodel.Claim( const i: Integer ): Integer;
var
  j: integer;
begin
  Result := 0;
  with EP[ cEP0 ].xInDep.Items[ 1 ] do begin
    for j:=2 to cMaxClaim+1 do
      if ( GetValue( i, j ) > 0 ) then
        Inc( Result );
  end;
end;

Function TDSmodel.NResPar: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i:=1 to NrOfDepVar do
    Result := Result + Claim( i );
end;

Function TDSmodel.ModelID: Word;
begin
  with EP[ cEP0 ].xInDep.Items[ 0 ] do
    Result := Trunc( GetValue( cmpModelID, 1 ) ); {-Don't check modelID here!}
end;

Function TDSmodel.ReadyToRun: Boolean;
begin
  with EP[ cEP0 ].xInDep.Items[ 0 ] do
    Result := ( GetValue( cmpReadyToRun, 1 ) > cNotReadyToRun );
end;

Procedure TDSmodel.SetReadyToRun( const Value: Boolean );
begin
  with EP[ cEP0 ].xInDep.Items[ 0 ] do
    if Value then
      SetValue(  cmpReadyToRun, 1, cReadyToRun )
    else
      SetValue(  cmpReadyToRun, 1, cNotReadyToRun );
end;

Procedure TDSmodel.Integrate( x1, x2: Double; var IErr: Integer );
var
  ModelProfile: PModelProfile; {-Hiermee wordt op deze plaats niks gedaan}
  Context: Tcontext;
begin
  IErr := cNoError;
  if not ReadyToRun then begin
    IErr := cModelIsNotReadyToRun; Exit;
  end;
  if ( x2 > x1 ) then begin {-dx > 0: vooruit in de tijd}
    Inherited Integrate( ystart, x1, x2, EP, DerivsProc, IErr );
    if ( IErr = cNoError ) then begin
      Context := Algorithme;
	  DerivsProc( x2, ystart, dydx, EP, Direction, Context, ModelProfile, IErr );
	end;
  end else begin {-Stationaire berekening}
    Context := ProfileReset;
	DerivsProc( x2, ystart, dydx, EP, Direction, Context, ModelProfile, IErr );
  end;
end;

Destructor TDSmodel.Destroy;
var
  i: Integer;
begin
  Try
    FreeLibrary( DLLdsModel ); {-Drop handle to DLLdsModel}
    for i:=0 to Length( EP ) - 1 do begin
      if ( EP[ i ] <> NIL ) then begin
        EP[ i ].free;
        EP[ i ] := NIL;
      end;
    end;
    SetLength( EP, 0 );
    ystart.free;
    dydx.free;
  except
  end;
  Inherited Destroy;
end;

Function TDSmodel.NrOfDepVar: Integer;
begin
  Result := ystart.NrOfElements;
end;

Function TDSmodel.NrOfOutputTimes: Integer;
begin
  Result := 0;
  if ReadyToRun then
    Result := EP[ cEP1 ].xInDep.Items[ 0 ].GetNCols;
end;

Function TDSmodel.OutputTime( const i: Integer ): Double;
begin
  Result := 0;
  if ReadyToRun and ( i <= NrOfOutputTimes ) and ( i >= 1 ) then
    Result := EP[ cEP1 ].xInDep.Items[ 0 ].Getvalue( 1, i );
end;

Function TDSmodel.Transient: Boolean;
begin
  Result := not ( ( NrOfOutputTimes = 1 ) and ( OutputTime( 1 ) = 0 ) );
end;

Procedure TDSmodel.Run( var ResultBuf: TDoubleMatrix; var IErr: Integer );
var
  i: Integer;
  x1, x2, dx: Double;
  ystart_at_x1: TLargeRealArray; {-Nodig om AvSpeeds te kunnen berekenen}
  {-bij niet-stationaire berekeningen Transient=true)}

Procedure FillRecordInResultBuf( const Row: Integer; var IErr: Integer );
var
  i,               {-Index in indep. var. array}
  Col,             {-Column in ResultBuf}
  k,               {-Claimindex}
  Ncl,             {-Nr. of columns claimed in Resultbuf}
  PT: Integer;     {-Processing-type needed to obtain result in ResultBuf}
  ValueOfResVar,   {-Value of Result variable}
  Uitsp,           {-Uitspoeling in tijdsinterval dx [M/L^2]}
  Inf,             {-Infiltation in time-interval dx [L]; must be > 0}
  Gift,            {-(fertilizer, pesticide) gift [M/L^2]}
  Scale: Double;   {-Scale-factor to multiply result with}
Const
  {-Processing-types }
  cPTnoProcessing = 1; {-No processing}
  cPTavSpeed      = 2; {-Average speed}
  cPTConc         = 3; {-Concentration}
  cPTFraction     = 4; {-Fraction of input}
  cPTexp10        = 5; {-10^Av}

Procedure Get_PT_and_Scale( const i, k: Integer; var PT: Integer;
          var Scale: Double );
  {-Processing-type needed to obtain result in ResultBuf by dep. variable i;
    claimindex k.
    Rem:
    - ystart[ 1 ] is reserved for infiltration in case the cPTConc option is
      used as a processing type;
    - ystart[ 2 ] is reserved for fertilizer, pesticide etc. gift in case the
      cPTFraction option is used as a processing type.}
begin
  with EP[ cEP0 ].xInDep.Items[ 1 ] do begin
    PT    := Trunc( GetValue( i, 1 + k ) );
    Scale := GetValue( i, 1 + cMaxClaim + k );
  end;
end; {-Procedure Get_PT_and_Scale}

Procedure LimitValueOfResVar( var ValueOfResVar: Double );
  {- Limiteer de uitvoerwaarden omdat deze anders niet kunnen worden weergegeven
     in de ado-sets van het *.flo-bestand}
const
  cMinAbsAdoValue = 0.100000000000E-99;
  cMaxAbsAdoValue = 9.999999999999E+99;
begin
  if ( ( Abs( ValueOfResVar ) < cMinAbsAdoValue ) and
            ( ValueOfResVar <> 0 ) ) then begin
    if ( ValueOfResVar > 0 ) then
      ValueOfResVar := cMinAbsAdoValue
    else
      ValueOfResVar := -cMinAbsAdoValue;
    {$ifdef test2}
    if test2 then begin
      Application.MessageBox( 'Limiting ValueOfResVar', 'Info', MB_OKCANCEL );
      test2 := false;
    end;
    {$endif}
  end else if ( Abs( ValueOfResVar ) > cMaxAbsAdoValue ) then begin
    if ( ValueOfResVar > 0 ) then
      ValueOfResVar := cMaxAbsAdoValue
    else
      ValueOfResVar := -cMaxAbsAdoValue;
    {$ifdef test2}
    if test2 then begin
      Application.MessageBox( 'Limiting ValueOfResVar', 'Info', MB_OKCANCEL );
      test2 := false;
    end;
    {$endif}
  end;
end; {-Procedure LimitValueOfResVar}

begin
  IErr := cNoError;
  Col := 1;
  for i:=1 to NrOfDepVar do begin
    Ncl := Claim( i );
    for k:=1 to Ncl do begin {-For all claims}
      Inc( Col );            {-Reserve a column in ResultBuf}
      ValueOfResVar := cResultUndefined;
      Get_PT_and_Scale( i, k, PT, Scale );
      if ( dx > 0 ) then begin
        Case PT of
          cPTnoProcessing: ValueOfResVar := Scale * ystart[ i ];
          cPTavSpeed: ValueOfResVar := Scale *
                      ( ystart[ i ] - ystart_at_x1[ i ] ) / dx;
          cPTConc:
            begin
              Uitsp := ystart[ i ] - ystart_at_x1[ i ];
              if ( Uitsp < 0 ) then begin
                IErr := cNegativeMassInConcCalculation; Exit;
              end;
              Inf := ystart[ 1 ] - ystart_at_x1[ 1 ];
              if ( Inf <= MinSingle ) then begin
                IErr := cNegativeInfiltrInConcCalculation; Exit;
              end;
              ValueOfResVar := Scale * Uitsp / Inf; {-[M/L^3]}
            end;
          cPTFraction:
            begin
              Uitsp := ystart[ i ] - ystart_at_x1[ i ];
              if ( Uitsp < 0 ) then begin
                IErr := cNegativeMassInConcCalculation; Exit;
              end;
              Gift := ystart[ 2 ] - ystart_at_x1[ 2 ];
              if ( Gift <= MinSingle ) then begin
                IErr := cNegativeGiftInFractionCalculation; Exit;
              end;
              ValueOfResVar := Scale * Uitsp / Gift; {[-]}
            end;
          cPTexp10: ValueOfResVar :=
            Scale * Power( 10, ( ystart[ i ] - ystart_at_x1[ i ] ) / dx );
        else
          IErr := cInvalidProcType; Exit;
        end;
      end else begin {-Alleen de snelheden dydx zijn berekend}
        Case PT of
          cPTnoProcessing: ValueOfResVar := Scale * ystart[ i ];
          cPTavSpeed: ValueOfResVar := Scale * dydx[ i ];
          cPTConc:
            begin
              Uitsp := dydx[ i ];
              if ( Uitsp < 0 ) then begin
                IErr := cNegativeMassInConcCalculation; Exit;
              end;
              Inf := dydx[ 1 ];
              if ( Inf <= MinSingle ) then begin
                IErr := cNegativeInfiltrInConcCalculation; Exit;
              end;
              ValueOfResVar := Scale * Uitsp / Inf; {-[M/L^3]}
            end;
          cPTFraction: begin
            Uitsp := dydx[ i ];
            if ( Uitsp < 0 ) then begin
              IErr := cNegativeMassInConcCalculation; Exit;
            end;
            Gift := dydx[ 2 ];
            if ( Gift <= MinSingle ) then begin
              IErr := cNegativeGiftInFractionCalculation; Exit;
            end;
            ValueOfResVar := Scale * Uitsp / Gift; {[-]}
          end;
          cPTexp10: ValueOfResVar := Scale * Power( 10, dydx[ i ] );
        else
          IErr := cInvalidProcType; Exit;
        end;
      end;
      LimitValueOfResVar( ValueOfResVar );
      ResultBuf.SetValue(  Row, Col, ValueOfResVar );
    end; {-for k}
  end; {-for i}
end; {-Procedure FillRecordInResultBuf}

Procedure SetYstart_at_x1;
var i: Integer;
begin                                    
  for i:=1 to NrOfDepVar do
    ystart_at_x1[ i ] := ystart[ i ];
end;

{$ifdef test3}
function MessageDlgCenter(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons): Integer;
var R: TRect;
begin
  if not Assigned(Screen.ActiveForm) then
  begin
    Result := MessageDlg(Msg, DlgType, Buttons, 0);
  end else
  begin
    with CreateMessageDialog(Msg, DlgType, Buttons) do
    try
      GetWindowRect(Screen.ActiveForm.Handle, R);
      Left := R.Left + ((R.Right - R.Left) div 2) - (Width div 2);
      Top := R.Top + ((R.Bottom - R.Top) div 2) - (Height div 2);
      Result := ShowModal;
    finally
      Free;
    end;
  end;
end;
{$endif}

begin

  if not ReadyToRun then begin {-Bail out if not ready to run}
    IErr := cModelIsNotReadyToRun; Exit;
  end;

  if not PrepareYstartForRun( IErr ) then Exit;

  try
    if Transient then
      ystart_at_x1 := TLargeRealArray.Create( NrOfDepVar, nil );
  except
    IErr := cErrorCreatingYstart_at_x1; exit;
  end;

  {-First column in ResultBuf contains output-times}

  for i:=1 to NrOfOutputTimes do
    ResultBuf.SetValue( i, 1, OutputTime( i ) );

  {$ifdef test3}
//    Application.MessageBox( 'i:=1 to NrOfOutputTimes...', 'Info', MB_OKCANCEL );
  {$endif}
  x1 := 0; {-Assume run starts at t=0}
  for i:=1 to NrOfOutputTimes do begin
    x2 := OutputTime( i );
    dx := x2 - x1;
    {-Negatieve tijdsintervallen worden niet gewaardeerd...}
    if ( dx < 0 ) then begin
      IErr := cNegativeTimeIntervalSpecified;
      if Transient then ystart_at_x1.free;
      exit;
    end;
    if Transient then
      SetYstart_at_x1; {-Veelal nodig in de verwerking vh uitvoer-resultaat,
                         bijvoorbeeld PT=cPTavSpeed}
    {$ifdef test3}
//      ShowMessage( 'Integrate. x1, x2 ,dx=' + FloatToStr( x1 ) +  ' ' +
//      FloatToStr( x2 ) + ' ' + FloatToStr( dx ) );
      MessageDlgCenter('Integrate. x1, x2 ,dx=' + FloatToStr( x1 ) +  ' ' +
        FloatToStr( x2 ) + ' ' + FloatToStr( dx ),  mtInformation, [mbOK] );
    {$endif}
    if ( dx >= 0 ) then begin
      Inc( iCount );
      Try
        Integrate( x1, x2, IErr ); {-Als x1=x2, dan wordt hier alleen een momen-
                                  tane snelheid berekend (dydx) }
      except
        Application.MessageBox( PChar( 'Error in integration: ' + IntToStr( iCount ) +
          ' x1, x2= ' + FloatToStr( x1 ) + ' ' + FloatToStr( x2 )  ),
                              'Info', MB_OK );
        IErr := cIntegrationError;
      end;

    end;
    {$ifdef test3}
//    Application.MessageBox( 'Integration finished', 'Info', MB_OKCANCEL );
    {$endif}
    {-Beeindig run als er een fout in de integratie is opgetreden. De mogelijk
      foute integratie-resultaten worden dus niet in 'ResultBuf' geplaatst}
    if ( IErr <> cNoError ) then begin
      if Transient then ystart_at_x1.free;
      exit;
    end;

    FillRecordInResultBuf( i, IErr ); {-Process result}

    {-Ook tijdens het bewerken van het integratie-resultaat kan wat fout gaan:
      nog een reden om 'run' te beeindigen }
    if ( IErr <> cNoError ) then begin
      if Transient then ystart_at_x1.free;
      exit;
    end;

    x1 := x2; {-Eind-tijdstip x2 is het startput voor de volgende integratie
                (x1)}
  end;
end;

{$define zip}

{$ifndef zip}
Function SaveTExtParToStream( const DSbootFileNameBIN: String; var ExtPar: TextPar ): Boolean;
var
  SaveStream: TFileStream;
begin
  SaveStream := TFileStream.Create( DSbootFileNameBIN, fmCreate );
  {SysUtils.DeleteFile( DSbootFileNameBIN );}
  Result := ExtPar.SaveToStream( SaveStream );
  SaveStream.free;
end;

Function LoadTExtParFromStream( const DSbootFileNameBIN: String; var ExtPar: TextPar ): Boolean;
var
  LoadStream: TFileStream;
begin
  LoadStream := TFileStream.Create( DSbootFileNameBIN, fmOpenRead );
  Result := ExtPar.LoadFromStream( LoadStream );
  LoadStream.free;
end;
{$endif}


{$ifdef zip}

Function SaveTExtParToStream( const DSbootFileNameBIN: String; var ExtPar: TextPar ): Boolean;
var
  SaveStream, LInput, Loutput: TFileStream;
  LZip: TZCompressionStream;
  TMPfileName: TFileName;
begin
  TMPfileName := ChangeFileExt( DSbootFileNameBIN, '.tmp' );
  SaveStream := TFileStream.Create( TMPfileName, fmCreate );
  Result := ExtPar.SaveToStream( SaveStream );
  {ShowMessage( format( 'SaveStream has %d bytes', [SaveStream.Size] ) );}
  SaveStream.free;

  LInput := TFileStream.Create( TMPfileName, fmOpenRead );
  LOutput := TFileStream.Create( DSbootFileNameBIN, fmCreate );
  LZip := TZCompressionStream.Create( clFastest, LOutput );
  LZip.CopyFrom( LInput, 0 );    {-Compress data }
  {ShowMessage( format( 'ZipStream has %d bytes', [LZip.Size] ) );}
  LZip.Free; LInput.Free; LOutput.Free;
  if not SysUtils.DeleteFile( TMPfileName ) then begin
    ShowMessage( Format( 'Cannot deleteFile %s.', [TMPfileName] ) );
  end;
end;

Function LoadTExtParFromStream( const DSbootFileNameBIN: String; var ExtPar: TextPar ): Boolean;
var
  LInput, LOutput: TFileStream;
  LUnZip: TZDecompressionStream;
  TMPfileName: TFileName;
begin
  TMPfileName := ChangeFileExt( DSbootFileNameBIN, '.tmp' ); {-Name of uncompressed file}
  LInput  := TFileStream.Create( DSbootFileNameBIN, fmOpenRead ); {-Compressed file}
  {ShowMessage( format( 'LInput has %d bytes', [LInput.Size] ) );}
  LOutput := TFileStream.Create( TMPfileName, fmCreate ); {-Uncompressed file}
  LUnZip  := TZDecompressionStream.Create( LInput );
  LOutput.CopyFrom( LUnZip, LUnZip.Size );   { Decompress data. }
  {ShowMessage( format( 'LOutput has %d bytes', [LOutput.Size] ) );}
  LUnZip.Free;  LInput.Free; {-Close compressed file} LOutput.Free; {-Close uncompressed file}

    {-Open uncompressed file for reading}
  LOutput := TFileStream.Create( TMPfileName, fmOpenRead );
  Result  := ExtPar.LoadFromStream( LOutput );
  LOutput.Free;
  if not SysUtils.DeleteFile( TMPfileName ) then begin
    ShowMessage( Format( 'Cannot deleteFile %s.', [TMPfileName] ) );
  end;
end;

{$endif}

  {-Initiate EP[cEP0] from file.
   If *.BP0 is newer then *.EP0, use *.BP0 (=binary file).
   If *.BP0 not so or *.BP0: use *.EP0 and create *.BP0}
Function DefaultBootEPFromTextFile( const EpDir: String;
  const BootEpArrayOption: TBootEpArrayOption; const ModelID,
  NrOfDepVar, nDC, NrXIndepTbls, NrXDepTbls: Integer; var Indx: Integer;
  var EP: TExtParArray ): Integer;
var
  FileBase, DSbootLOGFileName, DSbootFileName, DSbootFileNameBIN: String;
  f, lf: TextFile;
  DateTimeOfDSbootFile, DateTimeOfDSbootFileBIN: TDateTimeInfoRec;
  EPisLoadedFromBINfile: Boolean;

 {-Check and prepare a loaded EP[cEP0]}
  Function CheckAndPrepareEP0: Integer;
  begin
    {Result := cUnknownError;}
    with EP[ cEP0 ] do begin
      if ( xInDep.Count < NrXIndepTbls ) then begin
        ShowMessage( IntToStr( xInDep.Count ) );
        Result := cNotEnoughXIndepTblsInEP0; Exit;
      end;
      if xDep.Count < NrXDepTbls then begin
        Result := cNotEnoughXdepTblsInEP0; Exit;
      end;
      if not ( xInDep.Items[ 0 ].GetNRows = cNr_TINTode_Create_Settings  ) then begin
        Result := cInvalidNr_TINTode_Create_Settings; Exit;
      end;
      if not ( ( xInDep.Items[ 1 ].GetNRows >= NrOfDepVar  ) and
               ( xInDep.Items[ 1 ].GetNCols >= cNrOfDepVarOptions  ) ) then begin
        Result := cDimensionsOfDepVarTableInvalid; Exit;
      end;
      {-Zet gereserveerde waarden in xInDep.Items[ 0&1 ]}
      with xIndep do begin
        with Items[ 0 ] do begin
          SetValue( cmpModelID, 1, ModelID );
          SetValue( cmpReadyToRun, 1, cNotReadyToRun );
          SetValue( cmpnDc, 1, nDc );
        end;
      end;
      {-Settings in Items[ 1 ] are NOT changed}
    end;
    Result := cNoError;
  end; {-Function CheckAndPrepareEP0}

Begin
  Indx := cBootEPArrayVariantIndexUnknown;
  if ( BootEpArrayOption = cBootEPFromTextFile ) then begin
    FileBase          := EPDir    + cDSbootFileName + IntToStr( ModelID );
    DSbootLOGFileName := ExpandFileName( FileBase + cDSbootLogFileNameExt );
    try
      AssignFile( lf, DSbootLOGFileName ); Rewrite( lf );
    except
      Result := cUnableToCreateBootLogFile;
      MessageDlg( 'Error ' + IntToStr( Result ) + ':' + #13 +
                  'Unable to create boot-logfile: ' + #13 +
                  '"' + DSbootLOGFileName + '".', mtError, [mbOK], 0 );
      Exit;
    end;
    DSbootFileName := ExpandFileName( FileBase + cDSbootFileNameExt );
    If not FileExists( DSbootFileName ) then begin
      Result := cBootFileDoesNotExist;
      Writeln( lf, 'BootFile: "' + DSbootFileName + '" does not exist.' );
      CloseFile( lf ); Exit;
    end;

    FileGetDateTimeInfo( DSbootFileName, DateTimeOfDSbootFile );
    Writeln( lf, Format( 'TimeStamp of bootfile [%s]: [' + DateTimeToStr( DateTimeOfDSbootFile.TimeStamp ) + ']', [DSbootFileName] ) );

    EPisLoadedFromBINfile := false;
    DSbootFileNameBIN := ChangeFileExt( DSbootFileName, cDSbbootFileNameExtBIN );
    if FileGetDateTimeInfo( DSbootFileNameBIN, DateTimeOfDSbootFileBIN ) then begin {-BIN file exists}
      Writeln( lf, format( 'TimeStamp of bootfile [%s]: [%s].', [DSbootFileNameBIN, DateTimeToStr( DateTimeOfDSbootFileBIN.TimeStamp )] ) );
      if ( DateTimeOfDSbootFile.TimeStamp < DateTimeOfDSbootFileBIN.TimeStamp ) and {-BIN file is newer then EP0 file en...}
        not LoadTExtParFromStream( DSbootFileNameBIN, EP[ cEP0 ] ) then begin {-Het lukt niet om BIN-file te gebruiken}
        Result := cFailToBootEPArrayFromBIN;
        Writeln( lf, Format( 'Fail to boot EP[ cEP0 ] from file [%s].', [DSbootFileNameBIN] ) );
        CloseFile( lf ); Exit;
      end else begin {-Het is gelukt om BIN file te lezen}
        Result := CheckAndPrepareEP0;
        if ( Result <> cNoError ) then begin
          Writeln( lf, Format( 'Fail to boot EP[ cEP0 ] from file [%s].', [DSbootFileNameBIN] ) );
          CloseFile( lf ); Exit;
        end;
        Writeln( lf, Format( 'EP[ cEP0 ] booted from file [%s]:', [DSbootFileNameBIN] ) );
        Writeln( lf, Format( '%d xInDepTables and %d xDepTables )',
          [EP[ cEP0 ].xInDep.Count, EP[ cEP0 ].xDep.Count] ) );
        EPisLoadedFromBINfile := true;
      end;
    end;

    if not EPisLoadedFromBINfile then begin  {-Try to load from EP0 (text) file}
      try
        AssignFile( f, DSbootFileName );  Reset( f );
        Readln( f ); {Scip first line}
        EP[ cEP0 ].ReadxInDepFromTextFile( f );
        EP[ cEP0 ].ReadxDepFromTextFile( f );
        Result := CheckAndPrepareEP0;
        if ( Result <> cNoError ) then begin
          Writeln( lf, Format( 'Fail to boot EP[ cEP0 ] from file [%s].', [DSbootFileName] ) );
          CloseFile( f ); CloseFile( lf ); Exit;
        end;
        CloseFile( f );
        Writeln( lf, Format( 'EP[ cEP0 ] booted from file [%s].', [DSbootFileName] ) );
      except
        Result := cFileFailureInBootingEP0;
        try CloseFile( f ); CloseFile( lf ); except end; Exit;
      end; {-try}

      {-Save BIN file if this file is not present or older then EP0 (text) file}
      if not FileExists( DSbootFileNameBIN ) or
        ( DateTimeOfDSbootFile.TimeStamp > DateTimeOfDSbootFileBIN.TimeStamp ) then begin
        if not SaveTExtParToStream( DSbootFileNameBIN, EP[ cEP0 ] ) then
          Writeln( lf, Format( 'Could not save EP[ cEP0 ] to file [%s].', [DSbootFileNameBIN] ) )
        else begin
          FileGetDateTimeInfo( DSbootFileNameBIN, DateTimeOfDSbootFileBIN );
          Writeln( lf, Format( 'EP[ cEP0 ] saved to file [%s]; TimeStamp = [%s]',
            [DSbootFileNameBIN, DateTimeToStr( DateTimeOfDSbootFileBIN.TimeStamp ) ] ) );
          end;
      end;
    end;

    CloseFile( lf );

  end; {-if ( BootEpArrayOption = cBootEPFromTextFile )}

  SetCurrent_xs( 0, EP );
  SetAnalytic_DerivsProc( False, EP );
  Result := cNoError;
  Indx   := cBoot0;
end;

Function DefaultTestBootEPFromTextFile( const EpDir: String;
  const BootEpArrayOption: TBootEpArrayOption; const ModelID,
  NrXDepTbls: Integer; var Indx: Integer; var EP: TExtParArray ): Integer;
  {Initiate EP[cEP1]}
const
  cMinNrXIndepTbls = 1;
var
  FileBase, DSbootLOGFileName, DSbootFileName, DSbootFileNameBIN: String;
  f, lf: TextFile;
  DateTimeOfDSbootFile, DateTimeOfDSbootFileBIN: TDateTimeInfoRec;
  EPisLoadedFromBINfile: Boolean;

 {-Check and prepare a loaded EP[cEP1]}
 {-Er moet minimaal 1 tijdsonafhankelijke tabel zijn: de eerste tabel bevat
   nml. de gewenste uitvoertijdstippen (=xInDep.Items[ 0 ]);
   Het aantal tijdsafhankelijke (=xy-tabellen) is minimaal NrXDepTbls (->
   xDep.Items[ 0..NrXdepTbls ])}
  Function CheckAndPrepareEP1: Integer;
  begin
    with EP[ cEP1 ] do begin
      if ( xInDep.Count < cMinNrXIndepTbls ) then begin
        Result := cNotEnoughXIndepTblsInEP1; Exit;
      end;
      if ( xDep.Count < NrXdepTbls ) then begin
        Result := cNotEnoughXdepTblsInEP1; Exit;
      end;
      if not ( xInDep.Items[ 0 ].GetNRows = 1 )and {-uitv.tijdst.op 1 regel}
             ( xInDep.Items[ 0 ].GetNCols >= 1 ) then begin {-min. 1 uitv. tijdstip}
        Result := cDimensionsOfOutputTimesTableInvalid; Exit;
      end;
    end;
    Result := cNoError;
  end; {-Function CheckAndPrepareEP1}

Begin
  Indx   := cBootEPArrayVariantIndexUnknown;
  if ( BootEpArrayOption = cBootEPFromTextFile ) then begin

      FileBase := EPDir + cDSbootFileName + IntToStr( ModelID );
      DSbootLOGFileName := ExpandFileName( FileBase + cDSTestBootLogFileNameExt );
      Try
        AssignFile( lf, DSbootLOGFileName ); Rewrite( lf );
      Except
        Result := cUnableToCreateBootLogFile;
        MessageDlg( 'Error ' + IntToStr( Result ) + ':' + #13 +
                    'Unable to create boot-logfile: ' + #13 +
                    '"' + DSbootLOGFileName + '".', mtError, [mbOK], 0 );
        Exit;
      End;

      DSbootFileName := ExpandFileName( FileBase + cDSTestFileNameExt );
      If not FileExists( DSbootFileName ) then begin
        Result := cBootFileDoesNotExist;
        Writeln( lf, 'BootFile: "' + DSbootFileName + '" does not exist.' );
        CloseFile( lf ); Exit;
      end;

      FileGetDateTimeInfo( DSbootFileName, DateTimeOfDSbootFile );
      Writeln( lf, Format( 'TimeStamp of bootfile [%s]: [' + DateTimeToStr( DateTimeOfDSbootFile.TimeStamp ) + ']', [DSbootFileName] ) );

      EPisLoadedFromBINfile := false;
      DSbootFileNameBIN := ChangeFileExt( DSbootFileName, cDSTestFileNameExtBIN );
      if FileGetDateTimeInfo( DSbootFileNameBIN, DateTimeOfDSbootFileBIN ) then begin {-BIN file exists}
        Writeln( lf, format( 'TimeStamp of bootfile [%s]: [%s].', [DSbootFileNameBIN, DateTimeToStr( DateTimeOfDSbootFileBIN.TimeStamp )] ) );
        if ( DateTimeOfDSbootFile.TimeStamp < DateTimeOfDSbootFileBIN.TimeStamp ) and {-BIN file is newer then EP0 file en...}
          not LoadTExtParFromStream( DSbootFileNameBIN, EP[ cEP1 ] ) then begin {-Het lukt niet om BIN-file te gebruiken}
          Result := cFailToBootEPArrayFromBIN;
          Writeln( lf, Format( 'Fail to boot EP[ cEP1 ] from file [%s].', [DSbootFileNameBIN] ) );
          CloseFile( lf ); Exit;
        end else begin {-Het is gelukt om BIN file te lezen}
          Result := CheckAndPrepareEP1;
          if ( Result <> cNoError ) then begin
            Writeln( lf, Format( 'Fail to boot EP[ cEP1 ] from file [%s].', [DSbootFileNameBIN] ) );
            CloseFile( lf ); Exit;
          end;
          Writeln( lf, Format( 'EP[ cEP1 ] booted from file [%s]:', [DSbootFileNameBIN] ) );
          Writeln( lf, Format( '%d xInDepTables and %d xDepTables )',
            [EP[ cEP1 ].xInDep.Count, EP[ cEP1 ].xDep.Count] ) );
          EPisLoadedFromBINfile := true;
        end;
      end;

    if not EPisLoadedFromBINfile then begin  {-Try to load from EP1 (text) file}
      try
        AssignFile( f, DSbootFileName );  Reset( f );
        Readln( f ); {Scip first line}
        EP[ cEP1 ].ReadxInDepFromTextFile( f );
        EP[ cEP1 ].ReadxDepFromTextFile( f );
        Result := CheckAndPrepareEP1;
        if ( Result <> cNoError ) then begin
          Writeln( lf, Format( 'Fail to boot EP[ cEP1 ] from file [%s].', [DSbootFileName] ) );
          CloseFile( f ); CloseFile( lf ); Exit;
        end;
        CloseFile( f );
        Writeln( lf, Format( 'EP[ cEP1 ] booted from file [%s].', [DSbootFileName] ) );
      except
        Result := cFileFailureInBootingEP1;
        try CloseFile( f ); CloseFile( lf ); except end; Exit;
      end; {-try}

      {-Save BIN file if this file is not present or older then EP0 (text) file}
      if not FileExists( DSbootFileNameBIN ) or
        ( DateTimeOfDSbootFile.TimeStamp > DateTimeOfDSbootFileBIN.TimeStamp ) then begin
        if not SaveTExtParToStream( DSbootFileNameBIN, EP[ cEP1 ] ) then
          Writeln( lf, Format( 'Could not save EP[ cEP1 ] to file [%s].', [DSbootFileNameBIN] ) )
        else begin
          FileGetDateTimeInfo( DSbootFileNameBIN, DateTimeOfDSbootFileBIN );
          Writeln( lf, Format( 'EP[ cEP1 ] saved to file [%s]; TimeStamp = [%s]',
            [DSbootFileNameBIN, DateTimeToStr( DateTimeOfDSbootFileBIN.TimeStamp ) ] ) );
          end;
      end;
    end;

    CloseFile( lf );

  end; {-if ( BootEpArrayOption = cBootEPFromTextFile )}
  Result := cNoError;
  Indx   := cBoot1;
end;

Procedure SetReadyToRun( var EP: TExtParArray );
begin
  EP[ cEP0 ].xIndep.Items[ 0 ].SetValue( cmpReadyToRun, 1, cReadyToRun );
end;

begin
  Direction    := FrWrd;
  iCount       := 0;
  EpDir        := AlgRootDir;
  {$ifdef test2}
  test2        := true;
  {$endif}
end.


