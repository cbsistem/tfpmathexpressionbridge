unit FPMathExpressionBridge;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpexprpars_wp, mpMath_wp, Math;

type
  TIdentifierParse = procedure(Index: integer; AName: string; out AValue: real) of object;

  TExprFunc = procedure(var Result: TFPExpressionResult; const Args: TExprParameterArray);

  TEvalueteResult = record
      Value: real;
      IsValid: boolean;
  end;

type
    TFPMathExpressionBridge = class(TComponent)
    private
      {Private declarations}
      //FAbout : boolean;
      FParser: TFPExpressionParser;
      FIdentifierDefList: TList;   //list of TFPExprIdentifierDef

      FExpression: string;
      FVariableOfFunc: string;
      FVarIndex: integer;

      FExpressionList: TStrings;
      FVariableList: TStrings;     //variables...
      FConstantList: TStrings;     //variables...

      FOnVariableParse: TIdentifierParse;   //variables...
      FOnConstantParse: TIdentifierParse;   //variables...

      //procedure SetAbout(Value : boolean);
      procedure SetExpressionList(AValue: TStrings);
      procedure SetVariableList(AValue: TStrings);
      procedure SetConstantList(AValue: TStrings);

      procedure DoVariableParse(Index: integer; AName: string; out AValue: real);
      procedure DoConstantParse(Index: integer; AName: string; out AValue: real);

      procedure SetExpressionByIndex(Index: integer);
      function GetExpressionByIndex(Index: integer): string;
      function GetExpressionIndexByName(AName: string): integer;

      function GetVariableIndexByName(AName: string): integer;
      procedure SetExpression(Expr: string);
      procedure SetVariableOfFunc(AName: string);
    protected
      { Protected declarations }
    public
      {Public declarations}
      function EvalFunc(AValue: real): TEvalueteResult;   overload;   //one variable....
      function EvalFunc(AValues: array of real): TEvalueteResult;   overload; //many variables...

      function EvalExpr(Expr: string; ANamesVar: array of string): TEvalueteResult;  overload;
      function EvalExpr: TEvalueteResult;   overload;

      function AddVariable(AName: string): integer;
      function AddConstant(AName: string): integer;

      function AddExpression(Expr: string): integer;
      procedure AddFunction(AName: string; paramCount: integer; callFunc: TExprFunc);

      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      property Expression: string read FExpression write SetExpression;
      property VariableOfFunc: string read FVariableOfFunc write SetVariableOfFunc;
      property VarIndex: integer read FVarIndex;

    published
      {Published declarations }
      //property About : boolean read FAbout write SetAbout;
      property ListExpressions: TStrings read FExpressionList write SetExpressionList;
      property ListConstants: TStrings read FConstantList write SetConstantList;
      property ListVariables: TStrings read FVariableList write SetVariableList;
      property OnVariableParse: TIdentifierParse read FOnVariableParse write FOnVariableParse;
      property OnConstantParse: TIdentifierParse read FOnConstantParse write FOnConstantParse;
    end;

function TrimChar(sText: string; delchar: char): string;
function SplitStr(var theString: string; delimiter: string): string;

implementation

  (*
procedure TFPMathExpressionBridge.SetAbout(Value : boolean);
const CrLf = #13#10;
var msg : string;
begin
   if Value then begin
      msg := 'TFPMathExpressionBridge - Version 0.1 - 02/2013' + CrLf +
             'Author: Jose Marques Pessoa : jmpessoa__hotmail_com'+ CrLf +
             'TFPMathExpressionBridge is a warapper for [math]* subset'+ CrLf +
             'of TFPExpressionParse** attempting to establish a easy semantics'+ CrLf +
             'for construction of function graph and expression evaluete.'+ CrLf +
             '::Warning: at the moment this code is just a "proof-of-concept".';
      MessageDlg(msg, mtInformation, [mbOK], 0);
   end;
   FAbout := false;
end;
 *)

//sintax AddFunction('Delta', 3, @ExprDelta)
procedure TFPMathExpressionBridge.AddFunction(AName: string; paramCount: integer; callFunc: TExprFunc);
var
  strF: string;
  i: integer;
begin
   StrF:='';
   for i:=0 to paramCount-1 do strF:= StrF+ 'F';
   FParser.Identifiers.AddFunction(AName,'F',strF,callFunc);
end;

function TFPMathExpressionBridge.GetVariableIndexByName(AName: string): integer;
begin
   Result:= FVariableList.IndexOf(Uppercase(AName));
end;

procedure TFPMathExpressionBridge.SetExpressionList(AValue: TStrings);
begin
   FExpressionList.Assign(AValue);
end;

procedure TFPMathExpressionBridge.SetVariableList(AValue: TStrings);
begin
   FVariableList.Assign(AValue);
end;

procedure TFPMathExpressionBridge.SetConstantList(AValue: TStrings);
begin
   FConstantList.Assign(AValue);
end;

procedure TFPMathExpressionBridge.DoVariableParse(Index: integer; AName: string; out AValue: real);
begin
   if Assigned(FOnVariableParse) then FOnVariableParse(Index, AName, AValue);
end;

procedure TFPMathExpressionBridge.DoConstantParse(Index: integer; AName: string; out AValue: real);
begin
   if Assigned(FOnConstantParse) then FOnConstantParse(Index, AName, AValue);
end;

procedure TFPMathExpressionBridge.SetExpressionByIndex(Index: integer);
begin
    SetExpression(ListExpressions.Strings[Index]);
end;

function TFPMathExpressionBridge.GetExpressionByIndex(Index: integer): string;
begin
    Result:= ListExpressions.Strings[Index];
end;

function TFPMathExpressionBridge.GetExpressionIndexByName(AName: string): integer;
begin
   Result:= ListExpressions.IndexOf(AName);
end;

function TFPMathExpressionBridge.AddVariable(AName: string): integer;
var
   upperName: string;
begin
    Result:= -1;
    upperName:= Uppercase(Trim(AName));
    FVariableOfFunc:= upperName;

    if FVariableList.Count > 0 then
       Result:= FVariableList.IndexOf(upperName);

    if  Result < 0 then  //not found
    begin
       FVariableList.Add(upperName);
       FVarIndex:= FVariableList.Count-1;  //index
       Result:= FVarIndex;
    end;
end;

function TFPMathExpressionBridge.AddConstant(AName: string): integer;
var
   upperStr: string;
   cName: string;
begin
   upperStr:= Uppercase(Trim(AName));
   if Pos('=', upperStr) > 0 then
   begin
      cName:= SplitStr(upperStr, '=');
      Result:= FConstantList.IndexOf(cName);
      if Result < 0 then
      begin
         FConstantList.Add(cName);
         Result:= FConstantList.Count-1;  //index
      end;
   end
   else
   begin
      Result:= FConstantList.IndexOf(upperStr);
      if Result < 0 then
      begin
         FConstantList.Add(upperStr);
         Result:= FConstantList.Count-1;  //index
      end;
   end;
end;

function TFPMathExpressionBridge.AddExpression(Expr: string): integer;
var
   upperName: string;
begin
    Result:= -1;
    upperName:= Trim(Uppercase(Expr));

    if  FExpressionList.Count > 0 then
         Result:= FExpressionList.IndexOf(upperName);  //fixed! thanks to @mars

    if Result < 0 then  //not found ...
    begin
       FExpressionList.Add(upperName);
       Result:= FExpressionList.Count-1;   //index
    end;
end;

procedure TFPMathExpressionBridge.SetVariableOfFunc(AName: string);
begin
    FVariableOfFunc:= Uppercase(Trim(AName));
    FVarIndex:= GetVariableIndexByName(FVariableOfFunc);
    if FVarIndex < 0 then FVarIndex:= AddVariable(FVariableOfFunc);
end;

procedure TFPMathExpressionBridge.SetExpression(Expr: string);
var
   i, indexExpr: integer;
   upperExpr: string;
   cName: string;
   outValue: real;
begin
   for i:= 0 to FConstantList.Count-1 do
   begin
      if FParser.Identifiers.IndexOfIdentifier(FConstantList.Strings[i]) < 0 then  //if not exist --> Add
      begin
         cName:= FConstantList.Strings[i];
         DoConstantParse(i, cName, outValue); //event driver!
         FIdentifierDefList.Add(TFPExprIdentifierDef(
                      FParser.Identifiers.AddFloatVariable(cName, outValue)));
      end;
   end;
   if FVariableList.Count > 0 then
   begin
      for i:= 0 to FVariableList.Count-1 do
      begin
         if FParser.Identifiers.IndexOfIdentifier(FVariableList.Strings[i]) < 0 then  //if not exist --> Add
         begin
            FIdentifierDefList.Add(TFPExprIdentifierDef(
                      FParser.Identifiers.AddFloatVariable(FVariableList.Strings[i],0.0)));
         end;
      end;
   end;

   upperExpr:= Uppercase(Trim(Expr));

   indexExpr:= -1;
   if FExpressionList.Count > 0 then
       indexExpr:= FExpressionList.IndexOf(upperExpr); //fixed! thanks to @mars

   if  indexExpr < 0 then
      FExpressionList.Add(upperExpr);

   FExpression:= upperExpr;

   FParser.Expression:= FExpression;
end;

//assign values for the firsts "count" variables....
function TFPMathExpressionBridge.EvalFunc(AValues: array of real): TEvalueteResult;
Var
  E : TFPExpressionResult;
  i, j, count: integer;
begin
  Result.Value:= 0.0;
  Result.IsValid:= False;
  j:= FConstantList.Count; //constants...
  count:= Length(AValues);

  if FVariableList.Count > 0 then
  begin                      //j is the first index disponible for variables!
    for i:= 0 to count-1 do
    begin
      if (i+j) < FIdentifierDefList.Count then
           TFPExprIdentifierDef(FIdentifierDefList.Items[j+i]).AsFloat:= AValues[i];
    end;
    E:= FParser.Evaluate;
    if not IsNaN(E.ResFloat) then
    begin
       Result.Value:= E.ResFloat;
       Result.IsValid:= True;
    end;
  end;
end;

//only one variable... what?  just FVariableOfFunc/FVarIndex
function TFPMathExpressionBridge.EvalFunc(AValue: real): TEvalueteResult;
Var
  E: TFPExpressionResult;
  j: integer;
  indexVar: integer;
begin
  indexVar:= FVarIndex;
  Result.Value:= 0.0;
  Result.IsValid:= False;
  j:= FConstantList.Count; //constants...
  if FVariableList.Count > 0 then
  begin                    //j is the first index disponible for variables!
    TFPExprIdentifierDef(FIdentifierDefList.Items[j+indexVar]).AsFloat:= AValue;
    E:=FParser.Evaluate;
    if not IsNaN(E.ResFloat) then
    begin
       Result.Value:= E.ResFloat;
       Result.IsValid:= True;
    end;
  end
end;

function TFPMathExpressionBridge.EvalExpr: TEvalueteResult; // entirely event driver!
Var
  E: TFPExpressionResult;
  outValue: real;
  j, i: integer;
begin
  Result.Value:= 0.0;
  Result.IsValid:= False;   //j is the first index disponible for variables!

  j:= FConstantList.Count;  //NOTE: varibles index comes after last constant by code design!

  for i:= 0 to FVariableList.Count-1 do //variables
  begin
     DoVariableParse(i, FVariableList.Strings[i], outValue); //event driver!
     TFPExprIdentifierDef(FIdentifierDefList.Items[j+i]).AsFloat:= outValue; //NOTE: varibles index comes after last constant!
  end;

  E:=FParser.Evaluate;
  if not IsNaN(E.ResFloat) then
  begin
     Result.Value:= E.ResFloat;
     Result.IsValid:= True;
  end;

end;

function TFPMathExpressionBridge.EvalExpr(Expr: string; ANamesVar: array of string): TEvalueteResult;
var
  i, count: integer;
begin
  count:= Length(ANamesVar);

  for i:= 0 to count-1 do
     AddVariable(Uppercase(Trim(ANamesVar[i])));

  SetExpression(Expr);
  Result:= Self.EvalExpr; //here "Self" must have!
end;

constructor TFPMathExpressionBridge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FExpressionList:= TStringList.Create;
  FVariableList:= TStringList.Create;
  FConstantList:= TStringList.Create;
  FIdentifierDefList:= TList.Create;

  FParser:= TFPExpressionParser.Create(nil);   //nil?
  FParser.BuiltIns:= [bcMath];   //only Math functions!

  //Added by wp  .......... Thank you wp!!!
  FParser.Identifiers.AddFunction('Degtorad', 'F', 'F', @ExprDegtorad);
  FParser.Identifiers.AddFunction('Radtodeg', 'F', 'F', @ExprRadtodeg);
  FParser.Identifiers.AddFunction('Tan', 'F', 'F', @ExprTan);
  FParser.Identifiers.AddFunction('Cot', 'F', 'F', @ExprCot);
  FParser.Identifiers.AddFunction('Arcsin', 'F', 'F', @ExprArcsin);
  FParser.Identifiers.AddFunction('Arccos', 'F', 'F', @ExprArccos);
  FParser.Identifiers.AddFunction('Arccot', 'F', 'F', @ExprArccot);
  FParser.Identifiers.AddFunction('Cosh', 'F', 'F', @ExprCosh);
  FParser.Identifiers.AddFunction('Coth', 'F', 'F', @ExprCoth);
  FParser.Identifiers.AddFunction('Sinh', 'F', 'F', @ExprSinh);
  FParser.Identifiers.AddFunction('Tanh', 'F', 'F', @ExprTanh);
  FParser.Identifiers.AddFunction('Arcosh', 'F', 'F', @ExprArcosh);
  FParser.Identifiers.AddFunction('Arsinh', 'F', 'F', @ExprArsinh);
  FParser.Identifiers.AddFunction('Artanh', 'F', 'F', @ExprArtanh);
  FParser.Identifiers.AddFunction('Arcoth', 'F', 'F', @ExprArcoth);
  FParser.Identifiers.AddFunction('Sinc', 'F', 'F', @ExprSinc);
  FParser.Identifiers.AddFunction('Power', 'F', 'FF', @ExprPower);
  FParser.Identifiers.AddFunction('Hypot', 'F', 'FF', @ExprHypot);
  FParser.Identifiers.AddFunction('Log10', 'F', 'F', @ExprLog10);
  FParser.Identifiers.AddFunction('Log2', 'F', 'F', @ExprLog2);
  FParser.Identifiers.AddFunction('Erf', 'F', 'F', @ExprErf);
  FParser.Identifiers.AddFunction('Erfc', 'F', 'F', @ExprErfc);
  FParser.Identifiers.AddFunction('I0', 'F', 'F', @ExprI0);
  FParser.Identifiers.AddFunction('I1', 'F', 'F', @ExprI1);
  FParser.Identifiers.AddFunction('J0', 'F', 'F', @ExprJ0);
  FParser.Identifiers.AddFunction('J1', 'F', 'F', @ExprJ1);
  FParser.Identifiers.AddFunction('K0', 'F', 'F', @ExprK0);
  FParser.Identifiers.AddFunction('K1', 'F', 'F', @ExprK1);
  FParser.Identifiers.AddFunction('Y0', 'F', 'F', @ExprY0);
  FParser.Identifiers.AddFunction('Y1', 'F', 'F', @ExprY1);
  FParser.Identifiers.AddFunction('Max', 'F', 'FF', @ExprMax);
  FParser.Identifiers.AddFunction('Min', 'F', 'FF', @ExprMin);
end;

destructor TFPMathExpressionBridge.Destroy;
var
  i: integer;
begin
  FExpressionList.Free;
  FVariableList.Free;
  FConstantList.Free;
  for i:= 0 to FIdentifierDefList.Count-1 do
  begin
      TFPExprIdentifierDef(FIdentifierDefList.Items[i]).Free;
  end;
  FIdentifierDefList.Free;
  FreeAndNil(FParser);
  inherited Destroy;
end;
           {Generics function}
function TrimChar(sText: string; delchar: char): string;
var
  S: string;
begin
  S := sText;
  while Pos(delchar,S) > 0 do Delete(S,Pos(delchar,S),1);
  Result := S;
end;

function SplitStr(var theString: string; delimiter: string): string;
var
  i: integer;
begin
  Result:= '';
  if theString <> '' then
  begin
    i:= Pos(delimiter, theString);
    if i > 0 then
    begin
       Result:= Copy(theString, 1, i-1);
       theString:= Copy(theString, i+Length(delimiter), maxLongInt);
    end
    else
    begin
       Result := theString;
       theString := '';
    end;
  end;
end;

end.
