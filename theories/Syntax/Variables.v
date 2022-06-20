(******************************************************************************)
(* Copyright (c) 2021 Steven Keuchel                                          *)
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
     Strings.String.

From Equations Require Import
     Equations.

From Katamaran Require Export
     Context Prelude.

Local Set Implicit Arguments.

  Class VarKit : Type :=
    { (* Program variable names. *)
      𝑿 : Set; (* input: \MIX *)
      (* For name resolution we rely on decidable equality of program *)
  (*        variables. The functions in this module resolve to the closest binding *)
  (*        of an equal name and fill in the de Bruijn index automatically from *)
  (*        a successful resolution. *)
  (*      *)
      𝑿_eq_dec :> EqDec 𝑿;

      (* Names of logic variables. These represent immutable variables standing for *)
  (*        concrete value. *)
      𝑺 : Set; (* input: \MIS *)
      𝑺_eq_dec :> EqDec 𝑺;

      (* Conversion of program variables to logic variables. *)
      𝑿to𝑺 : 𝑿 -> 𝑺;

      (* Generation of logic variable names that is fresh for a given context *)
  (*        and that tries to reuse an optional old name. *)
      fresh : forall T, NCtx 𝑺 T -> option 𝑺 -> 𝑺;
    }.

  Definition DefaultVarKit : VarKit :=
    {| 𝑿        := string;
       𝑿_eq_dec := string_dec;
       𝑺        := string;
       𝑺_eq_dec := string_dec;
       𝑿to𝑺 x   := x;
       fresh    := ctx.fresh;
    |}.
