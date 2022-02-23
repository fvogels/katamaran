(******************************************************************************)
(* Copyright (c) 2022 Steven Keuchel                                          *)
(* All rights reserved.                                                       *)
(*                                                                            *)
(* Redistribution and use in source and binary forms, with or without         *)
(* modification, are permitted provided that the following conditions are     *)
(* met:                                                                       *)
(*                                                                            *)
(* 1. Redistributions of source code must retain the above copyright notice,  *)
(*    this list of conditions and the following disclaimer.                   *)
(*                                                                            *)
(* 2. Redistributions in binary form must reproduce the above copyright       *)
(*    notice, this list of conditions and the following disclaimer in the     *)
(*    documentation and/or other materials provided with the distribution.    *)
(*                                                                            *)
(* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        *)
(* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  *)
(* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR *)
(* PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR          *)
(* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,      *)
(* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,        *)
(* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR         *)
(* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF     *)
(* LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING       *)
(* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         *)
(* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               *)
(******************************************************************************)

From Coq Require Import
     Bool.Bool
     Logic.StrictProp
     PeanoNat
     NArith.BinNat.
From Equations Require Import
     Equations.
From Katamaran Require Import
     Prelude.
Local Set Implicit Arguments.

Declare Scope bv_scope.
Delimit Scope bv_scope with bv.
Declare Scope bv_bitstring_scope.
Delimit Scope bv_bitstring_scope with bits.

(* Yet another library for sized bitvectors. Ultimately, it would be great to
   consolidate this with for example: https://github.com/jasmin-lang/coqword or
   https://github.com/mit-plv/coqutil/tree/master/src/coqutil/Word

   Other resources include:
   https://github.com/arthuraa/coq-utils/blob/master/theories/word.v
   https://github.com/mit-plv/bbv
*)

Module bv.

  (* The given [positive] consist of fewer than n bits. *)
  Fixpoint at_most (n : nat) {struct n} : positive -> SProp :=
    match n with
    | O   => fun _ => sEmpty
    | S n => fun p =>
               match p with
               | xI p => at_most n p
               | xO p => at_most n p
               | xH => sUnit
               end
    end.

  Definition is_wf (n : nat) (bs : N) : SProp :=
    match bs with
    | N0     => sUnit
    | Npos p => at_most n p
    end.

  Record bv (n : nat) : Set :=
    mk { bin : N; _ : is_wf n bin }.
  Arguments mk {n} _ &.
  Set Transparent Obligations.

  Section Conversion.

    Fixpoint trunc (n : nat) (p : positive) : N :=
      match n with
      | 0   => N0
      | S n => match p with
                | xI p => N.succ_double (trunc n p)
                | xO p => N.double (trunc n p)
                | xH   => 1%N
                end
      end.

    Definition wf_double (n : nat) (x : N) :
      is_wf n x -> is_wf (S n) (N.double x) :=
       match x with
       | N0     => fun wf => wf
       | Npos p => fun wf => wf
       end.

    Definition wf_succ_double (n : nat) (x : N) :
      is_wf n x -> is_wf (S n) (N.succ_double x) :=
       match x with
       | N0     => fun wf => wf
       | Npos p => fun wf => wf
       end.

    Fixpoint wf_trunc n : forall p, is_wf n (trunc n p) :=
      match n with
      | O   => fun _ => stt
      | S n => fun p =>
                  match p with
                  | xI p => wf_succ_double n (trunc n p) (wf_trunc n p)
                  | xO p => wf_double n (trunc n p) (wf_trunc n p)
                  | xH   => stt
                  end
      end.

    Definition of_N {n} (bs : N) : bv n :=
      match bs with
      | N0     => mk N0 stt
      | Npos p => mk (trunc n p) (wf_trunc n p)
      end.

    (* Definition unsigned {n} (x : t n) : Z := *)
    (*   Z.of_N (bin x). *)
    (* Definition signed {n} (x : t n) : Z := *)
    (*   unsigned x - Zpower.two_power_nat (Nat.pred n). *)

    (* Definition of_Z {n} (x : Z) : t n := *)
    (*   of_N (Z.to_N (Z.modulo x (Zpower.two_power_nat n))). *)

  End Conversion.

  Section Constants.

    Definition zero n : bv n := mk 0 stt.
    Definition one n : bv n :=
      match n with
      | 0   => mk 0 stt
      | S _ => mk 1 stt
      end.

  End Constants.

  Section NoConfusion.

    Definition NoConfusion_bv {n} (x y : bv n) : Prop :=
      bin x = bin y.

    Definition noConfusion_bv {n} (x y : bv n) : NoConfusion_bv x y -> x = y :=
      match x with
      | mk x p =>
          match y with
          | mk y q =>
              fun e : x = y =>
                match e in _ = y return forall q : is_wf n y, mk x p = mk y q with
                | eq_refl => fun q => eq_refl
                end q
          end
      end.

    Definition noConfusion_inv_bv {n} (x y : bv n) : x = y -> NoConfusion_bv x y :=
      fun e => match e with
               | eq_refl => eq_refl
               end.

    #[program]
    Instance NoConfusionPackage_bv {n} : NoConfusionPackage (bv n) :=
      {| NoConfusion := @NoConfusion_bv n;
         noConfusion := @noConfusion_bv n;
         noConfusion_inv := @noConfusion_inv_bv n;
      |}.
    Next Obligation.
      intros n x y. destruct x as [x p], y as [y q].
      intros e. change_no_check (x = y) in e.
      destruct e. reflexivity.
    Qed.
    Next Obligation.
      intros n x y e. destruct e. destruct x. reflexivity.
    Qed.

  End NoConfusion.
  Local Existing Instance NoConfusionPackage_bv.

  Section Equality.

    Definition eqb {n : nat} (x y : bv n) : bool :=
      N.eqb (bin x) (bin y).

    Lemma eqb_spec {n : nat} : forall (x y : bv n), reflect (x = y) (eqb x y).
    Proof.
      intros [x wfx] [y wfy]. unfold eqb. cbn.
      destruct (N.eqb_spec x y); constructor.
      - now destruct e.
      - now intros p%(f_equal (@bin _)).
    Qed.

    Instance eqdec_bv {n : nat} : EqDec (bv n) :=
      fun x y =>
        match eqb_spec x y with
        | ReflectT _ e => left e
        | ReflectF _ n => right n
        end.

  End Equality.
  Local Existing Instance eqdec_bv.

  Section Arithmetic.

    Definition add {n} (x y : bv n) : bv n :=
      of_N (N.add (bin x) (bin y)).

    Definition sub {n} (x y : bv n) : bv n :=
      of_N (N.sub (N.shiftl_nat 1 n + bin x) (bin y)).

    Definition mul {n} (x y : bv n) : bv n :=
      of_N (N.mul (bin x) (bin y)).

  End Arithmetic.

  Section Logical.

    Definition land {n} (x y : bv n) : bv n :=
      of_N (N.land (bin x) (bin y)).

    Definition lor {n} (x y : bv n) : bv n :=
      of_N (N.lor (bin x) (bin y)).

    Definition lxor {n} (x y : bv n) : bv n :=
      of_N (N.lxor (bin x) (bin y)).

  End Logical.

  Section ListLike.

    Definition nil : bv 0 :=
      mk N0 stt.
    Definition cons [n] (b : bool) (xs : bv n) : bv (S n) :=
      match xs with
        mk bs wf =>
          if b
          then mk (N.succ_double bs) (wf_succ_double n bs wf)
          else mk (N.double bs) (wf_double n bs wf)
      end.

    Inductive NilView : bv 0 -> Set :=
    | nvnil : NilView nil.
    Definition nilView (xs : bv 0) : NilView xs :=
      match xs with
      | mk bs wf =>
          match bs return forall wf : is_wf 0 bs, NilView (mk bs wf) with
          | N0      => fun _ => nvnil
          | N.pos p => sEmpty_rect _
          end wf
      end.

    Inductive ConsView {n} : bv (S n) -> Set :=
    | cvcons (b : bool) (xs : bv n) : @ConsView n (cons b xs).
    Definition consView {n} (xs : bv (S n)) : ConsView xs :=
      match xs with
      | mk bs wf =>
          match bs return forall wf : is_wf (S n) bs, ConsView (mk bs wf) with
          | N0      => fun _ => cvcons false (mk 0 stt)
          | N.pos p =>
              match p with
              | xI p => fun wf => cvcons true  (mk (N.pos p) wf)
              | xO p => fun wf => cvcons false (mk (N.pos p) wf)
              | xH   => fun _  => cvcons true  (mk 0 stt)
              end
          end wf
      end.

    Inductive View : forall n, bv n -> Set :=
    | isnil  : @View 0 nil
    | iscons (b : bool) {n} (xs : bv n) : @View (S n) (cons b xs).
    Definition view {n} : forall xs : bv n, View xs :=
      match n return forall xs : bv n, View xs with
      | 0   => fun xs => match nilView xs with nvnil => isnil end
      | S n => fun xs => match consView xs with cvcons b xs => iscons b xs end
      end.

    Definition bv_rect (P : forall n : nat, bv n -> Type)
      (PO : P O nil)
      (PS : forall n (b : bool) (x : bv n), P n x -> P (S n) (cons b x)) :
      forall [n] (xs : bv n), P n xs :=
      fix t_rect (n : nat) : forall xs : bv n, P n xs :=
        match n with
        | 0   => fun xs => match nilView xs with
                           | nvnil => PO
                           end
        | S n => fun xs => match consView xs with
                           | cvcons b xs => PS n b xs (t_rect n xs)
                           end
        end.

    Definition fold_right (A : forall n : nat, Type)
      (c : forall n, bool -> A n -> A (S n)) (n : A O) :
      forall {m} (xs : bv m), A m :=
      bv_rect (fun m _ => A m) n (fun m b _ p => c m b p).

    Fixpoint fold_left {A : forall n : nat, Type}
      (c : forall n, A n -> bool -> A (S n)) (n : A O)
      [m] {struct m} : forall (xs : bv m), A m :=
      match m with
      | O    => fun xs =>
                  match nilView xs with
                  | nvnil => n
                  end
      | S m => fun xs  =>
                 match consView xs with
                 | cvcons b xs => fold_left (fun m => c (S m)) (c 0 n b) xs
                 end
      end.

    Definition app {m n} (xs : bv m) (ys : bv n) : bv (m + n) :=
      fold_right (fun m => bv (m + n)) (fun m => @cons (m + n)) ys xs.
    Global Arguments app : simpl never.

    Lemma app_nil {m} (xs : bv m) :
      app nil xs = xs.
    Proof. reflexivity. Defined.

    Definition app_cons b {m n} (xs : bv m) (ys : bv n) :
      app (cons b xs) ys = cons b (app xs ys).
    Proof. destruct xs as [[] ?], b; reflexivity. Defined.

    Inductive AppView m n : bv (m + n) -> Set :=
    | isapp (xs : bv m) (ys : bv n) : AppView _ _ (app xs ys).

    Import EqNotations.
    Definition avcons {m n} b {xs} (axs : AppView m n xs) :
      AppView (S m) n (cons b xs) :=
      match axs with
      | isapp xs ys => rew app_cons b xs ys in isapp (cons b xs) ys
      end.

    Fixpoint appView m n {struct m} : forall xs : bv (m + n), AppView _ _ xs :=
      match m with
      | O   => isapp nil
      | S m => fun xs =>
                 match consView xs with
                 | cvcons b xs => avcons b (appView m n xs)
                 end
      end.

    Definition rev_append {m n} (x : bv m) (y : bv n) : bv (m + n) :=
      fold_left (A := fun k => bv (k + n)) (fun k (z : bv (k + n)) b => cons b z) y x.
    Definition rev {m} (x : bv m) : bv m :=
      fold_left (fun k (z : bv k) b => cons b z) nil x.

    Lemma cons_inj [n] (x y : bool) (xs ys : bv n) :
      cons x xs = cons y ys -> x = y /\ xs = ys.
    Proof.
      destruct xs as [xs wfxs], ys as [ys wfys], x, y; intros Heq.
      - split; auto.
        apply noConfusion_inv in Heq.
        apply N.succ_double_inj in Heq.
        destruct Heq. reflexivity.
      - exfalso. apply noConfusion_inv in Heq.
        destruct xs, ys; discriminate Heq.
      - exfalso. apply noConfusion_inv in Heq.
        destruct xs, ys; discriminate Heq.
      - split; auto.
        apply noConfusion_inv in Heq.
        apply N.double_inj in Heq.
        destruct Heq. reflexivity.
    Qed.

  End ListLike.

  Section Finite.

    Fixpoint enumV {V : forall k : nat, Type} (c : forall k, bool -> V k -> V (S k))
      (n : V O) (m : nat) {struct m} : list (V m) :=
      match m with
      | O   => Datatypes.cons n Datatypes.nil
      | S m => Datatypes.app
                 (enumV (fun k => c (S k)) (c O false n) m)
                 (enumV (fun k => c (S k)) (c O true n) m)
      end.

    Lemma enumV_length {V : forall k : nat, Type} (c : forall k, bool -> V k -> V (S k)) (n : V O) (m : nat) :
      length (enumV c n m) = 2 ^ m.
    Proof.
      revert V c n. induction m; intros V c n.
      - reflexivity.
      - specialize (IHm (fun k => V (S k)) (fun k => c (S k))).
        cbn. now rewrite List.app_length, !IHm, Nat.add_0_r.
    Qed.

    Lemma enumV_inj {V : forall k : nat, Type} (c : forall k, bool -> V k -> V (S k))
      (c_inj : forall k b1 b2 v1 v2, c k b1 v1 = c k b2 v2 -> b1 = b2 /\ v1 = v2)
      (n1 n2 : V O) (m : nat) :
      enumV c n1 m = enumV c n2 m -> n1 = n2.
    Proof.
      revert V c c_inj n1 n2. induction m; intros V c c_inj n1 n2.
      - intros H%noConfusion_inv%(f_equal pr1). exact H.
      - cbn [enumV]. intros [H1 H2]%list.app_inj_1.
        apply (IHm (fun k => V (S k)) (fun k => c (S k))) in H1.
        + now apply c_inj in H1.
        + intros k. apply c_inj.
        + do 2 rewrite (@enumV_length (fun k => V (S k))).
          reflexivity.
    Qed.

    Lemma enumV_disjoint {V : forall k : nat, Type} (c : forall k, bool -> V k -> V (S k))
      (c_inj : forall k b1 b2 v1 v2, c k b1 v1 = c k b2 v2 -> b1 = b2 /\ v1 = v2)
      (n1 n2 : V O) (Heq : n1 <> n2) (m : nat) :
      forall (x : V m),
        base.elem_of_list x (enumV c n1 m) ->
        base.elem_of_list x (enumV c n2 m) -> False.
    Proof.
      revert V c c_inj n1 n2 Heq. induction m; intros V c c_inj n1 n2 Heq; cbn [enumV].
      - intros x xIn1%list.elem_of_list_singleton xIn2% list.elem_of_list_singleton.
        congruence.
      - specialize (IHm (fun k => V (S k)) (fun k => c (S k)) (fun k => c_inj (S k))).
        intros x [in1|in1]%list.elem_of_app [in2|in2]%list.elem_of_app;
          refine (IHm _ _ _ x in1 in2); intros []%c_inj; congruence.
    Qed.

    Lemma nodup_enumV {V : forall k : nat, Type} (c : forall k, bool -> V k -> V (S k))
      (c_inj : forall k b1 b2 v1 v2, c k b1 v1 = c k b2 v2 -> b1 = b2 /\ v1 = v2)
      (n : V O) (m : nat) : base.NoDup (enumV c n m).
    Proof.
      revert V c c_inj n. induction m; intros V c c_inj n; cbn [enumV].
      - apply list.NoDup_singleton.
      - specialize (IHm (fun k => V (S k)) (fun k => c (S k)) (fun k => c_inj (S k))).
        apply list.NoDup_app. repeat apply conj; auto.
        cbv - [enumV]. intros x.
        apply (@enumV_disjoint (fun k => V (S k)) (fun k => c (S k)) (fun k => c_inj (S k))).
        intros []%c_inj; congruence.
    Qed.

    Lemma elem_of_enumV {V : forall k : nat, Type} (c : forall k, bool -> V k -> V (S k)) (n : V O) (m : nat) :
      forall (b : bool) (x : V m),
        base.elem_of x (enumV c n m) ->
        base.elem_of (c m b x) (enumV c n (S m)).
    Proof.
      revert V c n. induction m; cbn; intros V c n b x xIn.
      - apply list.elem_of_list_singleton in xIn. subst x.
        destruct b; repeat constructor.
      - rewrite ?list.elem_of_app. rewrite list.elem_of_app in xIn.
        destruct xIn as [xIn|xIn];
          specialize (IHm (fun k => V (S k)) (fun k => c (S k)) _ b _ xIn);
          cbn in IHm; rewrite list.elem_of_app in IHm; intuition.
    Qed.

    Definition enum (n : nat) : list (bv n) :=
      enumV cons nil n.

    Lemma nodup_enum (n : nat) : base.NoDup (enum n).
    Proof. apply (nodup_enumV cons (@cons_inj)). Qed.

    Lemma elem_of_enum (m : nat) (x : bv m) : base.elem_of x (enum m).
    Proof.
      induction x using bv_rect.
      - now apply list.elem_of_list_singleton.
      - now apply elem_of_enumV.
    Qed.

    Instance finite_bv {n} : finite.Finite (bv n) :=
      {| stdpp.finite.enum         := enum n;
         stdpp.finite.NoDup_enum   := nodup_enum n;
         stdpp.finite.elem_of_enum := @elem_of_enum n;
      |}.

  End Finite.

  (* Big-endian bit strings (radix 2 strings). This type is defined by recursion
     over the number of bits and is less efficient than the subtype
     representation. The intended use case is exhaustive pattern matching over
     small bit vectors, i.e. up to ~7-8 bits. It can also be used to define
     constants of medium sized bit vectors (256-bits or so), but should be
     avoided for large bit vectors. *)
  Module bitstring.

    Local Set Transparent Obligations.

    (* A raw representation of bit string intended for the definition of the
       number notation. *)
    Inductive raw : Set := rI (_:raw) | rO (_:raw) | rN.
    Inductive null : Set := bN.
    Derive NoConfusion EqDec for null.

    Section Digit.
      Context {A : Set} {eqA : EqDec A}.
      Inductive digit : Set :=
      | bO (_:A) | bI (_:A).
      Derive NoConfusion EqDec for digit.
    End Digit.
    Global Arguments digit : clear implicits.

    (* Parse a decimal number into a raw bit string, failing if any digit other
       than 0 or 1 is used. This doesn't check the length of the decimal. *)
    Definition of_uint (u : Number.uint) : option raw :=
      let fix f (u : Decimal.uint) : option raw :=
        match u with
        | Decimal.Nil  => Some rN
        | Decimal.D0 u => option_map rO (f u)
        | Decimal.D1 u => option_map rI (f u)
        | _ => None
        end
      in match u with
         | Number.UIntDecimal u => f u
         | Number.UIntHexadecimal _ => None
         end.

    (* Unparse the given raw bit string. *)
    Definition to_uint (r : raw) : Number.uint :=
      let fix f (r : raw) : Decimal.uint :=
        match r with
        | rI r => Decimal.D1 (f r)
        | rO r => Decimal.D0 (f r)
        | rN   => Decimal.Nil
        end
      in Number.UIntDecimal (f r).

  End bitstring.

  Fixpoint bitstring (n : nat) : Set :=
    match n with
    | O   => bitstring.null
    | S n => bitstring.digit (bitstring n)
    end.

  Fixpoint bitstring_zeroes (n : nat) : bitstring n :=
    match n with
    | O   => bitstring.bN
    | S n => bitstring.bO (bitstring_zeroes n)
    end.

  Fixpoint fold_left_nat {A : forall n : nat, Type}
    (s : forall n, A n -> A (S n)) (z : A O) (m : nat) {struct m} : A m :=
    match m as n return (A n) with
    | O   => z
    | S n => fold_left_nat (fun k => s (S k)) (s 0 z) n
    end.

  Fixpoint fold_left_positive {A : forall n : nat, Type}
    (cI : forall n, A n -> A (S n))
    (cO : forall n, A n -> A (S n))
    (n : A O) {m : nat} (p : positive) {struct m} : A m :=
    match m with
    | O => n
    | S m =>
        match p with
        | xI p => fold_left_positive (fun k => cI (S k)) (fun k => cO (S k)) (cI 0 n) p
        | xO p => fold_left_positive (fun k => cI (S k)) (fun k => cO (S k)) (cO 0 n) p
        | xH   => fold_left_nat (fun k => cO (S k)) (cI 0 n) m
        end
    end.

  (* The subtype representation is little-endian while bitstring are big-endian.
     So use a fold-left to reverse the order *)
  Definition to_bitstring {n} (x : bv n) : bitstring n :=
    match x with
    | mk N0 _        => bitstring_zeroes n
    | mk (N.pos p) _ => fold_left_positive
                          (fun k => @bitstring.bI (bitstring k))
                          (fun k => @bitstring.bO (bitstring k))
                          bitstring.bN p
    end.

  Fixpoint fold_bitstring_left {A : forall k : nat, Type}
    (c : forall k, A k -> bool -> A (S k)) (n : A O)
    [m] {struct m} : forall (xs : bitstring m), A m :=
    match m with
    | O   => fun _ => n
    | S m =>
        fun xs =>
          match match xs with
                | bitstring.bO a => (false,a)
                | bitstring.bI a => (true,a)
                end with
          | (b,a) =>
              fold_bitstring_left (fun k => c (S k)) (c 0 n b) a
          end
    end.

  Definition of_bitstring : forall n, bitstring n -> bv n :=
    fold_bitstring_left (A := bv) (fun _ x b => cons b x) nil.

  Arguments to_bitstring [n] & _%bv.
  Arguments of_bitstring [n] & _%bits.

  Module notations.
    Open Scope bv_scope.
    Open Scope bv_bitstring_scope.

    (* Coq doesn't like the fixpoint definition of bitstrings. Squelch the
       warnings. *)
    Local Set Warnings "-via-type-mismatch -via-type-remapping".

    (* Number notation for bitstrings. This is a combination of the "Number
       Notation for radix 3" and "Number Notation with implicit arguments"
       examples given in
       https://coq.inria.fr/refman/user-extensions/syntax-extensions.html#number-notations
    *)
    Number Notation bitstring bitstring.of_uint bitstring.to_uint
           (via bitstring.raw mapping
                [[bitstring.bI] => bitstring.rI,
                 [bitstring.bO] => bitstring.rO,
                 [bitstring.bN] => bitstring.rN]) : bv_bitstring_scope.

    (* The number notation does not work for printing patterns in pattern
       matches, but curiously works for parsing. Possibly due to the via-type
       remappings whose warnings we silenced above. As a workaround we define
       printing only notations for the constructors that achieve the same result
       as printing the number notation. *)
    Notation "" := (bitstring.bN)
      (at level 0, right associativity, only printing) : bv_bitstring_scope.
    Notation "1 b" := (bitstring.bI b)
      (at level 0, right associativity, format "1 b", only printing) : bv_bitstring_scope.
    Notation "0 b" := (bitstring.bO b)
      (at level 0, right associativity, format "0 b", only printing) : bv_bitstring_scope.

    Notation "[ 'bits' x ]" := (of_bitstring x%bits)
      (format "[ 'bits'  x ]") : bv_scope.
    Notation "[ 'bits' ]" := (@of_bitstring 0 bitstring.bN)
      (format "[ 'bits' ]") : bv_scope.
    Notation "[ 'bits' [ n ] x ]" := (@of_bitstring n x%bits)
      (only parsing) : bv_scope.
    Notation "[ 'bits' [ 0 ] ]" := (@of_bitstring 0 bitstring.bN)
      (only parsing) : bv_scope.

    Notation "[ 'bv' x ]" := (mk x%xN stt) (format "[ 'bv'  x ]") : bv_scope.
    Notation "[ 'bv' [ n ] x ]" := (@mk n x%xN stt) (only parsing) : bv_scope.

  End notations.

End bv.
Export bv (bv).

Bind Scope bv_scope with bv.
Bind Scope bv_bitstring_scope with bv.bitstring.
Bind Scope bv_bitstring_scope with bv.bitstring.null.
Bind Scope bv_bitstring_scope with bv.bitstring.digit.

#[export] Existing Instance bv.NoConfusionPackage_bv.
#[export] Existing Instance bv.eqdec_bv.
#[export] Existing Instance bv.finite_bv.
