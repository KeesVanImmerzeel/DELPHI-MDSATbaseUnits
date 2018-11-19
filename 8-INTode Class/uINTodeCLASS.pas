unit uINTodeCLASS;
  {-Base-class for numerical integration}
interface

uses
  Windows, LargeArrays, ExtParU, USpeedProc, UAlgRout, UStepRout, uDCstepRout,
  UDriver, uError;

type
  TINTode = Class( TObject )
     private
       AlgRout:    TAlgRout;
       StepRout:   TStepRout;
       DCRoot:     TDCRoot;
       DCStepRout: TDCStepRout;
       Driver:     TDriver;
       DLLAlgRout, DLLStepRout, DLLDCRoot, DLLDCStepRout, DLLDriver: THandle;
     protected
     public
       nsubstep,    {-Nr.of sub-steps used in some Algorithm-routines}
       nstep,       {-Nr. of steps used in some Driver-routines}
       maxstp,      {-Max. nr of steps used in stepper routines with adaptive stepsize }
       nok,         {-The number of good steps taken in ,,}
       nbad: Integer; {-The number of bad steps taken (but retried and fixed) in ,,}
       htry,        {-Guessed first stepsize}
       hmin,        {-Minimum allowed stepsize}
       eps: Double; {-Accuracy (%, except for near zero crossings)}
       Constructor Create( const IAlgRout, IStepRout, IDCRoot, IDCStepRout,
         IDriver: Word; const I_nsubstep, I_nstep, I_maxstp: Integer;
         const I_htry, I_hmin, I_eps: Double; var Result: Integer ); reintroduce;
       Procedure Integrate( var ystart: TLargeRealArray;
                            x1, x2: Double; var EP: TExtParArray;
                            var DerivsProc: TDerivs; var IErr: Integer ); Virtual;
       Destructor Destroy; Override;
  end; {TINTode}

implementation

Constructor TINTode.Create( const IAlgRout, IStepRout, IDCRoot, IDCStepRout,
         IDriver: Word; const I_nsubstep, I_nstep, I_maxstp: Integer;
         const I_htry, I_hmin, I_eps: Double; var Result: Integer );
begin
  Inherited Create;

  nsubstep := I_nsubstep;
  nstep    := I_nstep;
  maxstp   := I_maxstp;
  nok      := 0;
  nbad     := 0;
  htry     := I_htry;
  hmin     := I_hmin;
  eps      := I_eps;
  
  Result := cNoError;

  {-Load AlgRout}
  DLLAlgRout := LoadLibrary( PChar( AlgRootDir+'AlgRout.dll' ) );
  if ( DLLAlgRout = 0 ) then begin
    Result := cUnableToLoadAlgRoutDLL;
    Exit;
  end else begin
    @AlgRout := GetProcAddress( DLLAlgRout, PChar( IAlgRout ) );
    if ( @AlgRout = nil ) then begin
      Result := cUnableToLocateAlgRoutProc; Exit;
    end;
  end;

  {-Load StepRout}
  DLLStepRout := LoadLibrary( PChar( AlgRootDir+'StepRout.dll' ) );
  if ( DLLStepRout = 0 ) then begin
    Result := cUnableToLoadStepRoutDLL;
    Exit;
  end else begin
    @StepRout := GetProcAddress( DLLStepRout, PChar( IStepRout ) );
    if ( @StepRout = nil ) then begin
      Result := cUnableToLocateStepRoutProc; Exit;
    end;
  end;

  {-Load DCRoot}
  DLLDCRoot := LoadLibrary( PChar( AlgRootDir+'DCRootRout.dll' ) );
  if ( DLLDCRoot = 0 ) then begin
    @DCRoot := nil;
  end else begin
    @DCRoot := GetProcAddress( DLLDCRoot, PChar( IDCRoot ) );
    if ( @DCRoot = nil ) then begin
    end;
  end;

  {-Load DCStepRout}
  DLLDCStepRout := LoadLibrary( PChar( AlgRootDir+'DCStepRout.dll' ) );
  if ( DLLDCStepRout = 0 ) then begin
    @DCStepRout := nil;
  end else begin
    @DCStepRout := GetProcAddress( DLLDCStepRout, PChar( IDCStepRout ) );
    if ( @DCStepRout = nil ) then begin
    end;
  end;

  {-Load Driver}
  DLLDriver := LoadLibrary( PChar( AlgRootDir+'Driver.dll' ) );
  if ( DLLDriver = 0 ) then begin
    Result := cUnableToLoadDriverDLL;
    Exit;
  end else begin
    @Driver := GetProcAddress( DLLDriver, PChar( IDriver ) );
    if ( @Driver = nil ) then begin
      Result := cUnableToLocateDriverProc; Exit;
    end;
  end;

  Result := cNoError;
end; {Constructor TINTode.Create}

Procedure TINTode.Integrate( var ystart: TLargeRealArray;
                             x1, x2: Double; var EP: TExtParArray;
                             var DerivsProc: TDerivs; var IErr: Integer );
begin
  Driver( ystart, htry, hmin, eps, x1, x2, EP, DerivsProc, AlgRout, StepRout,
          DCRoot, DCStepRout, nsubstep, nstep, maxstp, nok, nbad, IErr );
end;

Destructor TINTode.Destroy;
begin
  Try
    FreeLibrary( DLLAlgRout );
    FreeLibrary( DLLStepRout );
    FreeLibrary( DLLDCRoot );
    FreeLibrary( DLLDCStepRout );
    FreeLibrary( DLLDriver );
  except
  end;
  Inherited Destroy;
end;

end.
