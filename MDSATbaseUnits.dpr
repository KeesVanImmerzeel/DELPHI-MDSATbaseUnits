program MDSATbaseUnits;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ExtParU in '1-External Parameters\ExtParU.pas',
  uDCfunc in '2-DC functions\uDCfunc.pas',
  USpeedProc in '3-SpeedProcedures\USpeedProc.pas',
  UAlgRout in '4-Algorithm Routines\UAlgRout.pas',
  UStepRout in '5-Stepper Routines\UStepRout.pas',
  uDCstepRout in '6-DCstepper Routines\uDCstepRout.pas',
  UDriver in '7-Driver Routines\UDriver.pas',
  uINTodeCLASS in '8-INTode Class\uINTodeCLASS.pas',
  UDSmodel in '9-DSmodel\UDSmodel.pas',
  UdsModelS in 'X-DSmodelS\UdsModelS.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
