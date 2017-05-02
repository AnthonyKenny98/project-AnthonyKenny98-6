(* 
                         CS 51 Final Project
                         MiniML -- Evaluation
                             Spring 2017
*)

(* This module implements a small untyped ML-like language under
   various operational semantics.
 *)
    
open Expr ;;
open Printf;;
  
(* Exception for evaluator runtime, generated by a runtime error *)
exception EvalError of string ;;
(* Exception for evaluator runtime, generated by an explicit "raise" construct *)
exception EvalException of string;;


(* Environments and values *)

module type Env_type = sig
    type env
    type value =
      | Val of expr
      | Closure of (expr * env)
    val create : unit -> env
    val close : expr -> env -> value
    val lookup : env -> varid -> value
    val extend : env -> varid -> value ref -> env
    val env_to_string : env -> string
    val value_to_string : ?printenvp:bool -> value -> string
  end

module Env : Env_type =
  struct
    type env = (varid * value ref) list
     and value =
       | Val of expr
       | Closure of (expr * env)

    (* Creates an empty environment *)
    let create () : env = [] ;;

    (* Creates a closure from an expression and the environment it's
       defined in *)
    let rec close (exp : expr) (env : env) : value =
      Closure(exp, env)
   ;;

    (* Looks up the value of a variable in the environment *)
    let rec lookup (env : env) (varname : varid) : value =
      match env with
      | [] -> raise (EvalException ("Unbound Variable: " ^ varname))
      | h :: t -> let var, valref = h in 
        if var = varname then !valref else lookup t varname;;

    (* Returns a new environment just like env except that it maps the
       variable varid to loc *)
    let extend (env : env) (varname : varid) (loc : value ref) : env =
      (varname, loc) :: env ;;

    (* Returns a printable string representation of a value; the flag
       printenvp determines whether to include the environment in the
       string representation when called on a closure *)
    let rec value_to_string ?(printenvp : bool = true) (v : value) : string =
      match v with
      | Val exp -> sprintf "Val (%s)" (exp_to_string exp)
      | Closure (exp, env) -> 
          let envp = if printenvp then 
            List.fold_left (fun a (var, varref) -> sprintf "(%s : %s)" var (value_to_string !varref)) "" env
            else "env" in
            sprintf "Closure (%s %s)" (exp_to_string exp) envp;;

   (* Returns a printable string representation of an environment *)
   let env_to_string (env : env) : string =
      List.fold_left (fun a (var, varref) -> sprintf "(%s : %s)" var (value_to_string !varref)) "" env;;

  end
;;
  
(* The evaluation function: Returns the result of type `value` of
   evaluating the expression `exp` in the environment `env`. In this
   initial implementation, we just convert the expression unchanged to
   a value and return it. *)


(** The external evaluator, which can be either the identity function,
    the substitution model version or the dynamic or lexical
    environment model version. *)

let eval_t _env exp = exp ;;


let rec binop_eval (op : binop) (e1 : expr) (e2 : expr) : expr =
match e1, e2 with
  | Num _, Num _ ->
   (match op, e1, e2 with 
    | Plus, Num x, Num y -> Num (x + y)
    | Minus, Num x, Num y -> Num (x - y)
    | Times, Num x, Num y-> Num (x * y)
    | Equals, Num x, Num y-> Bool (x = y)
    | LessThan, Num x, Num y -> Bool (x < y))
  | _, _ -> raise (EvalException "Invalid Binop Expressions")
;;
let conditional_eval (condition : expr) (e1 : expr) (e2 :expr) : expr = 
  match condition with 
  | Bool b -> if b then e1 else e2 
  | _ -> raise (EvalException "Invalid Condition")
;;

let rec eval_s env exp : expr = 
  let eval = eval_s env in
  match exp with 
  | Var x -> raise (EvalException ("Unbound Variable: " ^ x))
  | Unop (n, e) -> Unop(n, eval e)
  | Binop (b, e1, e2) -> binop_eval b (eval e1) (eval e2)
  | Conditional (e1, e2, e3) -> 
            (match eval e1 with 
              | Bool b -> if b then (eval e2) else (eval e3) 
              | _ -> raise (EvalException "Invalid Condition"))
  | Let (v, e1, e2) -> eval (subst v e1 e2) (* NOT SURE - NEEDS THOUROUGH TESTING *)
  | Letrec (x, v, p) -> eval (subst x (subst x (Letrec(x, v, Var(x))) v) p)
  | App (f, e2) -> 
    (match eval f with
    | Fun (x, p) -> eval (subst x e2 p) 
    | _ -> raise (EvalException "wrong app")) 
  | x -> x
;;


let eval_d env exp =
match exp with 
  | Var x -> Env.lookup env x
  | Unop (n, e) -> Unop(n, eval e)
  | Binop (b, e1, e2) -> binop_eval b (eval e1) (eval e2)
  | Conditional (e1, e2, e3) -> conditional_eval (eval e1) (eval e2) (eval e3)
  | Let (v, e1, e2) -> eval (subst v e1 e2) (* NOT SURE - NEEDS THOUROUGH TESTING *)
  | Letrec (v, e1, e2) -> raise (EvalException ("Not yet implemented"))
  | App (f, e2) -> 
    (match eval_d env f with
    | Fun (x, p) -> 
    | _ -> raise (EvalException "application of non function")) 
  | x -> x 
;;




let eval_l _ = failwith "eval_l not implemented" ;;

let evaluate = eval_d ;;
