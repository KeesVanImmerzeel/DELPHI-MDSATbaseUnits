unit UAlgRout;
{-Exports type "TAlgRout"}

interface

uses
  LargeArrays, ExtParU, uDCfunc, USpeedProc, xyTable, Registry, Dialogs, FileCtrl,
  System.SysUtils, System.UITypes, Dutils;

type
  TAlgRout = Procedure( var y, dydx, yout: TLargeRealArray; var xs,
                        htot: Double; var nsubstep: Integer; var EP: TExtParArray;
                        var Direction: TDirection; var DerivsProc: TDerivs;
                        var IErr: Integer );
  {-Given values y and their derivatives dydx known at xs, advance the solution
    over an interval htot and return the incremented values as yout. Yout need
    not be a distinct array from y. If it is distinct, however, then y is
    returned undamaged. dydx is always returned undamaged. The routine
    DerivsProc returns derivatives dydx at x, given, x, the function values y
    and the external parameters EP. IErr=0 if no error occured during the
    calculation of yout. In most algorithme routines nsubstep (=the number of substeps
    to be used) is a dummy variable.}

Var
  AlgRootDir : String;
  Reg: TRegistry;
  KeyGood, DirExists: Boolean;

implementation

begin
  Reg     := TRegistry.Create;
  KeyGood := False;
  Try
    KeyGood := Reg.OpenKey(
      'Software\IDO Doesburg\MD-Sat\1.0', False );
    if KeyGood then begin
      KeyGood    := false;
      AlgRootDir := Reg.ReadString( 'RootDir' );
      if ( AlgRootDir <> '' ) then begin
        AlgRootDir := AlgRootDir + '\Bin\DSmodels\';
        KeyGood    := DirectoryExists( AlgRootDir );
      end;
    end;
  finally
    Reg.Free
  end;

  DirExists := directoryexists( AlgRootDir );

  if KeyGood and DirExists then begin
    {ShowMessage('AlgRootDir specified exists: [' + AlgRootDir + ']' );}
  end;
  if not KeyGood then begin
    MessageDlg( 'MD-Sat is not properly installed. Re-install!', mtError, [mbOk], 0 );
  end else if not DirExists then begin
    MessageDlg( 'AlgRootDir specified does not exist: "' + AlgRootDir + '"', mtError, [mbOk], 0 );
  end;

end.
