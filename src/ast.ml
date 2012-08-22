open Big_int
open Num
open Util
open Lexer

(* Some types for dealing with constants *)

type constant_value = (* ?constant_value *)
  IntConst of big_int
| BoolConst of bool
| StringConst of string
| NullConst

exception NotAConstant

(* Region: ASTs *)

type type_ = (* ?type_ *)
    Bool
  | Void
  | IntType
  | UShortType
  | ShortType
  | UintPtrType  (* The uintptr_t type from the C99 standard. It's an integer type big enough to hold a pointer value. *)
  | RealType
  | UChar
  | Char
  | StructType of string
  | PtrType of type_
  | FuncType of string   (* The name of a typedef whose body is a C function type. *)
  | InductiveType of string * type_ list
  | PredType of string list * type_ list * int option (* if None, not necessarily precise; if Some n, precise with n input parameters *)
  | PureFuncType of type_ * type_  (* Curried *)
  | ObjType of string
  | ArrayType of type_
  | StaticArrayType of type_ * int (* for array declarations in C *)
  | BoxIdType (* box type, for shared boxes *)
  | HandleIdType (* handle type, for shared boxes *)
  | AnyType (* supertype of all inductive datatypes; useful in combination with predicate families *)
  | TypeParam of string (* a reference to a type parameter declared in the enclosing datatype/function/predicate *)
  | InferredType of type_ option ref (* inferred type, is unified during type checking *)
  | ClassOrInterfaceName of string (* not a real type; used only during type checking *)
  | PackageName of string (* not a real type; used only during type checking *)
  | RefType of type_ (* not a real type; used only for locals whose address is taken *)
  | PluginInternalType of DynType.dyn

type prover_type = ProverInt | ProverBool | ProverReal | ProverInductive (* ?prover_type *)

(** Types as they appear in source code, before validity checking and resolution. *)
type type_expr = (* ?type_expr *)
    StructTypeExpr of loc * string
  | PtrTypeExpr of loc * type_expr
  | ArrayTypeExpr of loc * type_expr
  | StaticArrayTypeExpr of loc * type_expr (* type *) * int (* number of elements*)
  | ManifestTypeExpr of loc * type_  (* A type expression that is obviously a given type. *)
  | IdentTypeExpr of loc * string option (* package name *) * string
  | ConstructedTypeExpr of loc * string * type_expr list  (* A type of the form x<T1, T2, ...> *)
  | PredTypeExpr of loc * type_expr list * int option (* if None, not necessarily precise; if Some n, precise with n input parameters *)
  | PureFuncTypeExpr of loc * type_expr list   (* Potentially uncurried *)

(** An object used in predicate assertion ASTs. Created by the parser and filled in by the type checker.
    TODO: Since the type checker now generates a new AST anyway, we can eliminate this hack. *)
class predref (name: string) = (* ?predref *)
  object
    val mutable tparamcount: int option = None  (* Number of type parameters. *)
    val mutable domain: type_ list option = None  (* Parameter types. *)
    val mutable inputParamCount: int option option = None  (* Number of input parameters, or None if the predicate is not precise. *)
    method name = name
    method domain = match domain with None -> assert false | Some d -> d
    method inputParamCount = match inputParamCount with None -> assert false | Some c -> c
    method set_domain d = domain <- Some d
    method set_inputParamCount c = inputParamCount <- Some c
  end

type
  ident_scope = (* ?ident_scope *)
    LocalVar
  | PureCtor
  | FuncName
  | PredFamName
  | EnumElemName of big_int
  | GlobalName
  | ModuleName
  | PureFuncName

type
  operator =  (* ?operator *)
  | Add | Sub | Le | Lt | Eq | Neq | And | Or | Xor | Not | Mul | Div | Mod | BitNot | BitAnd | BitXor | BitOr | ShiftLeft | ShiftRight
and
  expr = (* ?expr *)
    True of loc
  | False of loc
  | Null of loc
  | Var of loc * string * ident_scope option ref  (* An identifier. *)
  | Operation of (* voor operaties met bovenstaande operators*)
      loc *
      operator *
      expr list *
      type_ list option ref
  | IntLit of loc * big_int * type_ option ref (* int literal*)
  | RealLit of loc * num
  | StringLit of loc * string (* string literal *)
  | ClassLit of loc * string (* class literal in java *)
  | Read of loc * expr * string (* lezen van een veld; hergebruiken voor java field access *)
  | ArrayLengthExpr of loc * expr
  | WRead of
      loc *
      expr *
      string (* parent *) *
      string (* field name *) *
      type_ (* range *) *
      bool (* static *) *
      constant_value option option ref *
      ghostness
  | ReadArray of loc * expr * expr
  | WReadArray of loc * expr * type_ * expr
  | Deref of loc * expr * type_ option ref (* pointee type *) (* pointer dereference *)
  | CallExpr of (* oproep van functie/methode/lemma/fixpoint *)
      loc *
      string *
      type_expr list (* type arguments *) *
      pat list (* indices, in case this is really a predicate assertion *) *
      pat list (* arguments *) *
      method_binding
  | ExprCallExpr of (* Call whose callee is an expression instead of a plain identifier *)
      loc *
      expr *
      expr list
  | WFunPtrCall of loc * string * expr list
  | WPureFunCall of loc * string * type_ list * expr list
  | WPureFunValueCall of loc * expr * expr list
  | WFunCall of loc * string * type_ list * expr list
  | WMethodCall of
      loc *
      string (* declaring class or interface *) *
      string (* method name *) *
      type_ list (* parameter types (not including receiver) *) *
      expr list (* args, including receiver if instance method *) *
      method_binding
  | NewArray of loc * type_expr * expr
  | NewObject of loc * string * expr list
  | NewArrayWithInitializer of loc * type_expr * expr list
  | IfExpr of loc * expr * expr * expr
  | SwitchExpr of
      loc *
      expr *
      switch_expr_clause list *
      (loc * expr) option * (* default clause *)
      (type_ * (string * type_) list * type_ list * type_) option ref (* used during evaluation when generating an anonymous fixpoint function, to get the prover types right *)
  | PredNameExpr of loc * string (* naam van predicaat en line of code*)
  | CastExpr of loc * bool (* truncating *) * type_expr * expr (* cast *)
  | Upcast of expr * type_ (* from *) * type_ (* to *)  (* Not generated by the parser; inserted by the typechecker. Required to prevent bad downcasts during autoclose. *)
  | WidenedParameterArgument of expr (* Appears only as part of LitPat (WidenedParameterArgument e). Indicates that the predicate parameter is considered to range over a larger set (e.g. Object instead of class C). *)
  | SizeofExpr of loc * type_expr
  | AddressOf of loc * expr
  | ProverTypeConversion of prover_type * prover_type * expr  (* Generated during type checking in the presence of type parameters, to get the prover types right *)
  | ArrayTypeExpr' of loc * expr (* horrible hack --- for well-formed programs, this exists only during parsing *)
  | AssignExpr of loc * expr * expr
  | AssignOpExpr of loc * expr * operator * expr * bool (* true = return value of lhs before operation *) * type_ list option ref * type_ option ref
  | InstanceOfExpr of loc * expr * type_expr
  | SuperMethodCall of loc * string * expr list
  | WSuperMethodCall of loc * string * expr list * (loc * ghostness * (type_ option) * (string * type_) list * asn * asn * ((type_ * asn) list) * visibility)
  | InitializerList of loc * expr list
and
  pat = (* ?pat *)
    LitPat of expr (* literal pattern *)
  | VarPat of loc * string (* var pattern, aangeduid met ? in code *)
  | DummyPat (*dummy pattern, aangeduid met _ in code *)
  | CtorPat of loc * string * pat list
  | WCtorPat of loc * string * type_ list * string * type_ list * type_ list * pat list
and
  switch_expr_clause = (* ?switch_expr_clause *)
    SwitchExprClause of loc * string * string list * expr (* switch uitdrukking *)
and
  language = (* ?language *)
    Java
  | CLang
and
  method_binding = (* ?method_binding *)
    Static
  | Instance
and
  visibility = (* ?visibility *)
    Public
  | Protected
  | Private
  | Package
and
  package = (* ?package *)
    PackageDecl of loc * string * import list * decl list
and
  import = (* ?import *)
    Import of
        loc *
        string *
        string option (* None betekent heel package, Some string betekent 1 ding eruit *)
and
  stmt = (* ?stmt *)
    PureStmt of (* Statement of the form /*@ ... @*/ *)
        loc *
        stmt
  | NonpureStmt of (* Nested non-pure statement; used for perform_action statements on shared boxes. *)
      loc *
      bool (* allowed *) *
      stmt
  | DeclStmt of (* enkel declaratie *)
      loc *
      (loc * type_expr * string * expr option * bool ref (* indicates whether address is taken *)) list
  | ExprStmt of expr
  | IfStmt of (* if  regel-conditie-branch1-branch2  *)
      loc *
      expr *
      stmt list *
      stmt list
  | SwitchStmt of (* switch over inductief type regel-expr- constructor)*)
      loc *
      expr *
      switch_stmt_clause list
  | Assert of loc * asn (* assert regel-predicate *)
  | Leak of loc * asn (* expliciet lekken van assertie, nuttig op einde van thread*)
  | Open of
      loc *
      expr option *  (* Target object *)
      string *
      type_expr list *  (* Type arguments *)
      pat list *  (* Indices for predicate family instance, or constructor arguments for predicate constructor *)
      pat list *  (* Arguments *)
      pat option  (* Coefficient for fractional permission *)
  | Close of
      loc *
      expr option *
      string *
      type_expr list *
      pat list *
      pat list *
      pat option
  | ReturnStmt of loc * expr option (*return regel-return value (optie) *)
  | WhileStmt of
      loc *
      expr *
      loop_spec option *
      expr option * (* decreases clause *)
      stmt list
  | BlockStmt of
      loc *
      decl list *
      stmt list *
      loc *
      string list ref
  | PerformActionStmt of
      loc *
      bool ref (* in non-pure context *) *
      string *
      pat list *
      loc *
      string *
      pat list *
      loc *
      string *
      expr list *
      stmt list *
      loc (* close brace of body *) *
      (loc * expr list) option *
      loc *
      string *
      expr list
  | SplitFractionStmt of (* split_fraction ... by ... *)
      loc *
      string *
      type_expr list *
      pat list *
      expr option
  | MergeFractionsStmt of (* merge_fraction ...*)
      loc *
      string *
      type_expr list *
      pat list
  | CreateBoxStmt of
      loc *
      string *
      string *
      expr list *
      (loc * string * string * expr list) list (* and_handle clauses *)
  | CreateHandleStmt of
      loc *
      string *
      string *
      expr
  | DisposeBoxStmt of
      loc *
      string *
      pat list *
      (loc * string * pat list) list (* and_handle clauses *)
  | LabelStmt of loc * string
  | GotoStmt of loc * string
  | NoopStmt of loc
  | InvariantStmt of
      loc *
      asn (* join point *)
  | ProduceLemmaFunctionPointerChunkStmt of
      loc *
      expr *
      (string * type_expr list * expr list * (loc * string) list * loc * stmt list * loc) option *
      stmt option
  | ProduceFunctionPointerChunkStmt of
      loc *
      string *
      expr *
      expr list *
      (loc * string) list *
      loc *
      stmt list *
      loc
  | Throw of loc * expr
  | TryCatch of
      loc *
      stmt list *
      (loc * type_expr * string * stmt list) list
  | TryFinally of
      loc *
      stmt list *
      loc *
      stmt list
  | Break of loc
  | SuperConstructorCall of loc * expr list
and
  loop_spec = (* ?loop_spec *)
  | LoopInv of asn
  | LoopSpec of asn * asn
and
  switch_stmt_clause = (* ?switch_stmt_clause *)
  | SwitchStmtClause of loc * expr * stmt list
  | SwitchStmtDefaultClause of loc * stmt list
and
  asn = (* A separation logic assertion *) (* ?asn *)
    PointsTo of (* toegang tot veld regel-expr-veld-pattern *)
        loc *
        expr *
        pat
  | WPointsTo of
      loc *
      expr *
      type_ *
      pat
  | PredAsn of (* Predicate assertion, before type checking *)
      loc *
      predref *
      type_expr list *
      pat list (* indices of predicate family instance *) *
      pat list
  | WPredAsn of (* Predicate assertion, after type checking. (W is for well-formed) *)
      loc *
      predref *
      bool * (* prefref refers to global name *)
      type_ list *
      pat list *
      pat list
  | InstPredAsn of
      loc *
      expr *
      string *
      expr * (* index *)
      pat list
  | WInstPredAsn of
      loc *
      expr option *
      string (* static type *) *
      class_finality (* finality of static type *) *
      string (* family type *) *
      string *
      expr (* index *) *
      pat list
  | ExprAsn of (* uitdrukking regel-expr *)
      loc *
      expr
  | Sep of (* separate conjunction *)
      loc *
      asn *
      asn
  | IfAsn of (* if-predicate in de vorm expr? p1:p2 regel-expr-p1-p2 *)
      loc *
      expr *
      asn *
      asn
  | SwitchAsn of (* switch over cons van inductive type regel-expr-clauses*)
      loc *
      expr *
      switch_asn_clause list
  | WSwitchAsn of (* switch over cons van inductive type regel-expr-clauses*)
      loc *
      expr *
      string * (* inductive type (fully qualified) *)
      switch_asn_clause list
  | EmpAsn of  (* als "emp" bij requires/ensures staat -regel-*)
      loc
  | ForallAsn of 
      loc *
      type_expr *
      string *
      expr
  | CoefAsn of (* fractional permission met coeff-predicate*)
      loc *
      pat *
      asn
  | PluginAsn of loc * string
  | WPluginAsn of loc * string list * Plugins.typechecked_plugin_assertion
  | EnsuresAsn of loc * asn
  | MatchAsn of loc * expr * pat
  | WMatchAsn of loc * expr * pat * type_
and
  switch_asn_clause = (* ?switch_asn_clause *)
  | SwitchAsnClause of
      loc * 
      string * 
      string list * 
      prover_type option list option ref (* Boxing info *) *
      asn (* clauses bij switch  regel-cons-lijst v var in cons-body *)
and
  func_kind = (* ?func_kind *)
  | Regular
  | Fixpoint
  | Lemma of bool (* indicates whether an axiom should be generated for this lemma *) * expr option (* trigger *)
and
  meth = (* ?meth *)
  | Meth of
      loc * 
      ghostness * 
      type_expr option * 
      string * 
      (type_expr * string) list * 
      (asn * asn * ((type_expr * asn) list)) option * 
      (stmt list * loc (* Close brace *)) option * 
      method_binding * 
      visibility *
      bool (* is declared abstract? *)
and
  cons = (* ?cons *)
  | Cons of
      loc * 
      (type_expr * string) list * 
      (asn * asn * ((type_expr * asn) list)) option * 
      (stmt list * loc (* Close brace *)) option * 
      visibility
and
  instance_pred_decl = (* ?instance_pred_decl *)
  | InstancePredDecl of loc * string * (type_expr * string) list * asn option
and
  class_finality =
  | FinalClass
  | ExtensibleClass
and
  decl = (* ?decl *)
    Struct of loc * string * field list option
  | Inductive of  (* inductief data type regel-naam-type parameters-lijst van constructors*)
      loc *
      string *
      string list *
      ctor list
  | Class of
      loc *
      bool (* abstract *) *
      class_finality *
      string *
      meth list *
      field list *
      cons list *
      string (* superclass *) *
      string list (* itfs *) *
      instance_pred_decl list
  | Interface of 
      loc *
      string *
      string list *
      field list *
      meth list *
      instance_pred_decl list
  | PredFamilyDecl of
      loc *
      string *
      string list (* type parameters *) *
      int (* number of indices *) *
      type_expr list *
      int option (* (Some n) means the predicate is precise and the first n parameters are input parameters *)
  | PredFamilyInstanceDecl of
      loc *
      string *
      string list (* type parameters *) *
      (loc * string) list *
      (type_expr * string) list *
      asn
  | PredCtorDecl of
      loc *
      string *
      (type_expr * string) list *
      (type_expr * string) list *
      asn
  | Func of
      loc *
      func_kind *
      string list *  (* type parameters *)
      type_expr option *  (* return type *)
      string *  (* name *)
      (type_expr * string) list *  (* parameters *)
      bool (* nonghost_callers_only *) *
      (string * type_expr list * (loc * string) list) option (* implemented function type, with function type type arguments and function type arguments *) *
      (asn * asn) option *  (* contract *)
      (stmt list * loc (* Close brace *)) option *  (* body *)
      method_binding *  (* static or instance *)
      visibility
  | TypedefDecl of
      loc *
      type_expr *
      string
  | FuncTypeDecl of
      loc *
      ghostness *
      type_expr option *
      string *
      string list *
      (type_expr * string) list *
      (type_expr * string) list *
      (asn * asn)
  | BoxClassDecl of
      loc *
      string *
      (type_expr * string) list *
      asn *
      action_decl list *
      handle_pred_decl list
  (* enum def met line - name - elements *)
  | EnumDecl of loc * string * (string * expr option) list
  | Global of loc * type_expr * string * expr option
  | UnloadableModuleDecl of loc
  | LoadPluginDecl of loc * loc * string
and (* shared box is deeltje ghost state, waarde kan enkel via actions gewijzigd worden, handle predicates geven info over de ghost state, zelfs als er geen eigendom over de box is*)
  action_decl = (* ?action_decl *)
  | ActionDecl of loc * string * (type_expr * string) list * expr * expr
and (* action, kan value van shared box wijzigen*)
  handle_pred_decl = (* ?handle_pred_decl *)
  | HandlePredDecl of loc * string * (type_expr * string) list * expr * preserved_by_clause list
and (* handle predicate geeft info over ghost state van shared box, zelfs als er geen volledige eigendom is vd box*)
  preserved_by_clause = (* ?preserved_by_clause *)
  | PreservedByClause of loc * string * string list * stmt list
and
  ghostness = (* ?ghostness *)
  | Ghost
  | Real
and
  field =
  | Field of (* ?field *)
      loc *
      ghostness *
      type_expr *
      string (* name of the field *) *
      method_binding *
      visibility *
      bool (* final *) *
      expr option
and
  ctor = (* ?ctor *)
  | Ctor of loc * string * type_expr list (* constructor met regel-naam-lijst v types v args*)
and
  member = (* ?member *)
  | FieldMember of field list
  | MethMember of meth
  | ConsMember of cons
  | PredMember of instance_pred_decl

let func_kind_of_ghostness gh =
  match gh with
    Real -> Regular
  | Ghost -> Lemma (false, None)
  
(* Region: some AST inspector functions *)

(*
Visual Studio format:
C:\ddd\sss.xyz(123): error VF0001: blah
C:\ddd\sss.xyz(123,456): error VF0001: blah
C:\ddd\sss.xyz(123,456-789): error VF0001: blah
C:\ddd\sss.xyz(123,456-789,123): error VF0001: blah
GNU format:
C:\ddd\sss.xyz:123: error VF0001: blah
C:\ddd\sss.xyz:123.456: error VF0001: blah
C:\ddd\sss.xyz:123.456-789: error VF0001: blah
C:\ddd\sss.xyz:123.456-789.123: error VF0001: blah
See
http://blogs.msdn.com/msbuild/archive/2006/11/03/msbuild-visual-studio-aware-error-messages-and-message-formats.aspx
and
http://www.gnu.org/prep/standards/standards.html#Errors
*)
  
let string_of_srcpos (p,l,c) = p ^ "(" ^ string_of_int l ^ "," ^ string_of_int c ^ ")"

let string_of_path (basedir, relpath) = concat basedir relpath

let string_of_loc ((p1, l1, c1), (p2, l2, c2)) =
  string_of_path p1 ^ "(" ^ string_of_int l1 ^ "," ^ string_of_int c1 ^
  if p1 = p2 then
    if l1 = l2 then
      if c1 = c2 then
        ")"
      else
        "-" ^ string_of_int c2 ^ ")"
    else
      "-" ^ string_of_int l2 ^ "," ^ string_of_int c2 ^ ")"
  else
    ")-" ^ string_of_path p2 ^ "(" ^ string_of_int l2 ^ "," ^ string_of_int c2 ^ ")"
let string_of_func_kind f=
  match f with
    Lemma(_) -> "lemma"
  | Regular -> "regular"
  | Fixpoint -> "fixpoint"
let tostring f=
  match f with
  Instance -> "instance"
  | Static -> "static"
let rec expr_loc e =
  match e with
    True l -> l
  | False l -> l
  | Null l -> l
  | Var (l, x, _) -> l
  | IntLit (l, n, t) -> l
  | RealLit (l, n) -> l
  | StringLit (l, s) -> l
  | ClassLit (l, s) -> l
  | Operation (l, op, es, ts) -> l
  | Read (l, e, f) -> l
  | ArrayLengthExpr (l, e) -> l
  | WRead (l, _, _, _, _, _, _, _) -> l
  | ReadArray (l, _, _) -> l
  | WReadArray (l, _, _, _) -> l
  | Deref (l, e, t) -> l
  | CallExpr (l, g, targs, pats0, pats,_) -> l
  | ExprCallExpr (l, e, es) -> l
  | WPureFunCall (l, g, targs, args) -> l
  | WPureFunValueCall (l, e, es) -> l
  | WFunPtrCall (l, g, args) -> l
  | WFunCall (l, g, targs, args) -> l
  | WMethodCall (l, tn, m, pts, args, fb) -> l
  | NewObject (l, cn, args) -> l
  | NewArray(l, _, _) -> l
  | NewArrayWithInitializer (l, _, _) -> l
  | IfExpr (l, e1, e2, e3) -> l
  | SwitchExpr (l, e, secs, _, _) -> l
  | SizeofExpr (l, t) -> l
  | PredNameExpr (l, g) -> l
  | CastExpr (l, trunc, te, e) -> l
  | Upcast (e, fromType, toType) -> expr_loc e
  | WidenedParameterArgument e -> expr_loc e
  | AddressOf (l, e) -> l
  | ArrayTypeExpr' (l, e) -> l
  | AssignExpr (l, lhs, rhs) -> l
  | AssignOpExpr (l, lhs, op, rhs, postOp, _, _) -> l
  | ProverTypeConversion (t1, t2, e) -> expr_loc e
  | InstanceOfExpr(l, e, tp) -> l
  | SuperMethodCall(l, _, _) -> l
  | WSuperMethodCall(l, _, _, _) -> l
  | InitializerList (l, _) -> l

let asn_loc p =
  match p with
    PointsTo (l, e, rhs) -> l
  | WPointsTo (l, e, tp, rhs) -> l
  | PredAsn (l, g, targs, ies, es) -> l
  | WPredAsn (l, g, _, targs, ies, es) -> l
  | InstPredAsn (l, e, g, index, pats) -> l
  | WInstPredAsn (l, e_opt, tns, cfin, tn, g, index, pats) -> l
  | ExprAsn (l, e) -> l
  | MatchAsn (l, e, pat) -> l
  | WMatchAsn (l, e, pat, tp) -> l
  | Sep (l, p1, p2) -> l
  | IfAsn (l, e, p1, p2) -> l
  | SwitchAsn (l, e, sacs) -> l
  | WSwitchAsn (l, e, i, sacs) -> l
  | EmpAsn l -> l
  | ForallAsn (l, tp, i, e) -> l
  | CoefAsn (l, coef, body) -> l
  | PluginAsn (l, asn) -> l
  | WPluginAsn (l, xs, asn) -> l
  | EnsuresAsn (l, body) -> l
  
let stmt_loc s =
  match s with
    PureStmt (l, _) -> l
  | NonpureStmt (l, _, _) -> l
  | ExprStmt e -> expr_loc e
  | DeclStmt (l, _) -> l
  | IfStmt (l, _, _, _) -> l
  | SwitchStmt (l, _, _) -> l
  | Assert (l, _) -> l
  | Leak (l, _) -> l
  | Open (l, _, _, _, _, _, coef) -> l
  | Close (l, _, _, _, _, _, coef) -> l
  | ReturnStmt (l, _) -> l
  | WhileStmt (l, _, _, _, _) -> l
  | Throw (l, _) -> l
  | TryCatch (l, _, _) -> l
  | TryFinally (l, _, _, _) -> l
  | BlockStmt (l, ds, ss, _, _) -> l
  | PerformActionStmt (l, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) -> l
  | SplitFractionStmt (l, _, _, _, _) -> l
  | MergeFractionsStmt (l, _, _, _) -> l
  | CreateBoxStmt (l, _, _, _, _) -> l
  | CreateHandleStmt (l, _, _, _) -> l
  | DisposeBoxStmt (l, _, _, _) -> l
  | LabelStmt (l, _) -> l
  | GotoStmt (l, _) -> l
  | NoopStmt l -> l
  | InvariantStmt (l, _) -> l
  | ProduceLemmaFunctionPointerChunkStmt (l, _, _, _) -> l
  | ProduceFunctionPointerChunkStmt (l, ftn, fpe, args, params, openBraceLoc, ss, closeBraceLoc) -> l
  | Break (l) -> l
  | SuperConstructorCall(l, _) -> l

let type_expr_loc t =
  match t with
    ManifestTypeExpr (l, t) -> l
  | StructTypeExpr (l, sn) -> l
  | IdentTypeExpr (l, _, x) -> l
  | ConstructedTypeExpr (l, x, targs) -> l
  | PtrTypeExpr (l, te) -> l
  | ArrayTypeExpr(l, te) -> l
  | PredTypeExpr(l, te, _) -> l
  | PureFuncTypeExpr (l, tes) -> l

let expr_fold_open iter state e =
  let rec iters state es =
    match es with
      [] -> state
    | e::es -> iters (iter state e) es
  and iterpats state pats =
    match pats with
      [] -> state
    | LitPat e::pats -> iterpats (iter state e) pats
    | _::pats -> iterpats state pats
  and itercs state cs =
    match cs with
      [] -> state
    | SwitchExprClause (l, cn, pats, e)::cs -> itercs (iter state e) cs
  in
  match e with
    True l -> state
  | False l -> state
  | Null l -> state
  | Var (l, x, scope) -> state
  | Operation (l, op, es, ts) -> iters state es
  | IntLit (l, n, tp) -> state
  | RealLit(l, n) -> state
  | StringLit (l, s) -> state
  | ClassLit (l, cn) -> state
  | Read (l, e0, f) -> iter state e0
  | ArrayLengthExpr (l, e0) -> iter state e0
  | WRead (l, e0, fparent, fname, frange, fstatic, fvalue, fghost) -> if fstatic then state else iter state e0
  | ReadArray (l, a, i) -> let state = iter state a in let state = iter state i in state
  | WReadArray (l, a, tp, i) -> let state = iter state a in let state = iter state i in state
  | Deref (l, e0, tp) -> iter state e0
  | CallExpr (l, g, targes, pats0, pats, mb) -> let state = iterpats state pats0 in let state = iterpats state pats in state
  | ExprCallExpr (l, e, es) -> iters state (e::es)
  | WPureFunCall (l, g, targs, args) -> iters state args
  | WPureFunValueCall (l, e, args) -> iters state (e::args)
  | WFunCall (l, g, targs, args) -> iters state args
  | WFunPtrCall (l, g, args) -> iters state args
  | WMethodCall (l, cn, m, pts, args, mb) -> iters state args
  | NewObject (l, cn, args) -> iters state args
  | NewArray (l, te, e0) -> iter state e0
  | NewArrayWithInitializer (l, te, es) -> iters state es
  | IfExpr (l, e1, e2, e3) -> iters state [e1; e2; e3]
  | SwitchExpr (l, e0, cs, cdef_opt, info) -> let state = itercs (iter state e0) cs in (match cdef_opt with Some (l, e) -> iter state e | None -> state)
  | PredNameExpr (l, p) -> state
  | CastExpr (l, trunc, te, e0) -> iter state e0
  | Upcast (e, fromType, toType) -> iter state e
  | WidenedParameterArgument e -> iter state e
  | SizeofExpr (l, te) -> state
  | AddressOf (l, e0) -> iter state e0
  | ProverTypeConversion (pt, pt0, e0) -> iter state e0
  | AssignExpr (l, lhs, rhs) -> iter (iter state lhs) rhs
  | AssignOpExpr (l, lhs, op, rhs, post, _, _) -> iter (iter state lhs) rhs
  | InstanceOfExpr(l, e, tp) -> iter state e
  | SuperMethodCall(_, _, args) -> iters state args
  | WSuperMethodCall(_, _, args, _) -> iters state args

(* Postfix fold *)
let expr_fold f state e = let rec iter state e = f (expr_fold_open iter state e) e in iter state e

let expr_iter f e = expr_fold (fun state e -> f e) () e

let expr_flatmap f e = expr_fold (fun state e -> f e @ state) [] e