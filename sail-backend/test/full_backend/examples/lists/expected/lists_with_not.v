From Coq Require Import
     Lists.List
     Strings.String
     ZArith.BinInt.

From Katamaran Require Import
     Semantics.Registers
     Program.

Import ctx.notations
       ctx.resolution
       ListNotations.

Local Open Scope string_scope.
Local Open Scope list_scope.



(*** TYPES ***)

Import DefaultBase.



(*** PROGRAM ***)

Module Import ListsProgram <: Program DefaultBase.

  Section FunDeclKit.

    Inductive Fun : PCtx -> Ty -> Set :=
    | is_empty : Fun ["l" ∷ (ty.list ty.int)] ty.bool
    | empty : Fun ["()" ∷ ty.unit] (ty.list ty.int)
    | onetwothree : Fun ["()" ∷ ty.unit] (ty.list ty.int)
    | last : Fun ["l" ∷ (ty.list ty.int)] (ty.prod ty.int ty.bool)
    | append : Fun ["l1" ∷ (ty.list ty.int); "l2" ∷ (ty.list ty.int)]
        (ty.list ty.int)
    | reverse_aux : Fun ["l" ∷ (ty.list ty.int); "acc" ∷ (ty.list ty.int)]
        (ty.list ty.int)
    | reverse : Fun ["l" ∷ (ty.list ty.int)] (ty.list ty.int)
    | reverse_bis : Fun ["l" ∷ (ty.list ty.int)] (ty.list ty.int).

    Definition 𝑭  : PCtx -> Ty -> Set := Fun.
    Definition 𝑭𝑿 : PCtx -> Ty -> Set := fun _ _ => Empty_set.
    Definition 𝑳  : PCtx -> Set := fun _ => Empty_set.

  End FunDeclKit.

  Include FunDeclMixin DefaultBase.

  Section FunDefKit.

    Definition fun_is_empty : Stm ["l" ∷ (ty.list ty.int)] ty.bool :=
      stm_match_list (stm_exp (exp_var "l")) (stm_exp (exp_true)) "h" "t"
        (stm_exp (exp_false)).

    Definition fun_empty : Stm ["()" ∷ ty.unit] (ty.list ty.int) :=
      stm_exp (exp_list []).

    Definition fun_onetwothree : Stm ["()" ∷ ty.unit] (ty.list ty.int) :=
      stm_exp (exp_list [exp_int 1%Z; exp_int 2%Z; exp_int 3%Z]).

    Definition fun_last : Stm ["l" ∷ (ty.list ty.int)] (ty.prod ty.int ty.bool) :=
      stm_match_list (stm_exp (exp_var "l"))
        (stm_exp (exp_binop bop.pair (exp_int 0%Z) (exp_false))) "h" "t"
        (stm_match_list (stm_exp (exp_var "t"))
          (stm_exp (exp_binop bop.pair (exp_var "h") (exp_true))) "h'" "t'"
          (call last (exp_var "t"))).

    Definition fun_append : Stm
        ["l1" ∷ (ty.list ty.int); "l2" ∷ (ty.list ty.int)] (ty.list ty.int) :=
      stm_match_list (stm_exp (exp_var "l1")) (stm_exp (exp_var "l2")) "h" "t"
        (let: "ga#0" := call append (exp_var "t") (exp_var "l2") in
          stm_exp (exp_binop bop.cons (exp_var "h") (exp_var "ga#0"))).

    Definition fun_reverse_aux : Stm
        ["l" ∷ (ty.list ty.int); "acc" ∷ (ty.list ty.int)] (ty.list ty.int) :=
      stm_match_list (stm_exp (exp_var "l")) (stm_exp (exp_var "acc")) "h" "t"
        (let: "ga#1" :=
          stm_exp (exp_binop bop.cons (exp_var "h") (exp_var "acc")) in
          call reverse_aux (exp_var "t") (exp_var "ga#1")).

    Definition fun_reverse : Stm ["l" ∷ (ty.list ty.int)] (ty.list ty.int) :=
      call reverse_aux (exp_var "l") (exp_list []).

    Definition fun_reverse_bis : Stm ["l" ∷ (ty.list ty.int)] (ty.list ty.int) :=
      stm_match_list (stm_exp (exp_var "l")) (stm_exp (exp_list [])) "h" "t"
        (let: "ga#2" := call reverse_bis (exp_var "t") in
          call append (exp_var "ga#2") (exp_list [exp_var "h"])).

    Definition FunDef {Δ τ} (f : Fun Δ τ) : Stm Δ τ :=
      match f in Fun Δ τ return Stm Δ τ with
      | is_empty => fun_is_empty
      | empty => fun_empty
      | onetwothree => fun_onetwothree
      | last => fun_last
      | append => fun_append
      | reverse_aux => fun_reverse_aux
      | reverse => fun_reverse
      | reverse_bis => fun_reverse_bis
      end.

  End FunDefKit.

  Include DefaultRegStoreKit DefaultBase.

  Section ForeignKit.
    Definition Memory : Set := unit.
    Definition ForeignCall {σs σ} (f : 𝑭𝑿 σs σ) (args : NamedEnv Val σs)
      (res : string + Val σ) (γ γ' : RegStore) (μ μ' : Memory) : Prop := False.
    Lemma ForeignProgress {σs σ} (f : 𝑭𝑿 σs σ) (args : NamedEnv Val σs) γ μ :
      exists γ' μ' res, ForeignCall f args res γ γ' μ μ'.
    Proof. destruct f. Qed.
  End ForeignKit.

  Include ProgramMixin DefaultBase.

End ListsProgram.

