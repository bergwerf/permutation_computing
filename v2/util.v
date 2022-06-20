(* Utilities based on std++. *)

From stdpp Require Export base numbers option list fin_maps.
From stdpp Require Import pmap.

Definition prod_swap {A} (p : A * A) :=
  match p with (x1, x2) => (x2, x1) end.

Definition keys `{FinMapToList K A M} (m : M) : list K :=
  (map_to_list m).*1.
  
Definition values `{FinMapToList K A M} (m : M) : list A :=
  (map_to_list m).*2.

Ltac simpl_lookup :=
  repeat match goal with
  | H : {[_:=_]} !! _ = Some _ |- _ =>
    apply lookup_singleton_Some in H as []
  | H : <[_:=_]> _ !! _ = Some _ |- _ =>
    apply lookup_insert_Some in H as [[]|[]]; subst
  | H : delete _ _ !! _ = Some _ |- _ =>
    apply lookup_delete_Some in H as []
  end.

Ltac simpl_elem_of :=
  repeat match goal with
  | H : (?x, ?y) ∈ map_to_list _ |- _ =>
    apply elem_of_map_to_list in H
  | H : ?x ∈ map_to_list _ |- _ =>
    destruct x
  | H : (?x, ?y) ∈ ?f <$> ?l |- _ =>
    apply elem_of_list_fmap in H as ([] & ? & H)
  | H : ?x ∈ ?f <$> ?l |- _ =>
    let y := fresh x in
    apply elem_of_list_fmap in H as (y & -> & H);
    rename y into x
  end.

Global Instance prod_swap_inj {X} :
  Inj eq eq (@prod_swap X).
Proof.
intros [] []; cbn; congruence.
Qed.

Lemma NoDup_keys `{FinMap K M} {A} (m : M A) :
  NoDup (keys m).
Proof.
apply NoDup_fst_map_to_list.
Qed.

Lemma elem_of_keys `{FinMap K M} {A} (m : M A) (k : K) :
  k ∈ keys m ↔ is_Some (m !! k).
Proof.
unfold keys; split; intros Hk.
simpl_elem_of; intuition. destruct Hk as [x Hx].
apply elem_of_list_fmap; exists (k, x); split; [done|].
apply elem_of_map_to_list; done.
Qed.

Lemma elem_of_values `{FinMap K M} {A} (m : M A) (x : A) :
  x ∈ values m ↔ ∃ k, m !! k = Some x.
Proof.
unfold values; split; intros Hx.
simpl_elem_of; exists k; done. destruct Hx as [k Hk].
apply elem_of_list_fmap; exists (k, x); split; [done|].
apply elem_of_map_to_list; done.
Qed.

Lemma list_difference_nil `{dec : EqDecision A} (l k : list A) :
  l ⊆ k -> list_difference l k = [].
Proof.
induction l; cbn; intros. done.
destruct decide_rel; set_solver.
Qed.

Lemma list_union_cancel `{dec : EqDecision A} (l k : list A) :
  l ⊆ k -> list_union l k = k.
Proof.
intros; unfold list_union;
rewrite list_difference_nil; done.
Qed.

Lemma list_union_sym `{dec : EqDecision A} (l k : list A) :
  NoDup l -> NoDup k -> list_union l k ≡ₚ list_union k l.
Proof.
intros; apply NoDup_Permutation.
1,2: apply NoDup_list_union; done.
intros; rewrite ?elem_of_list_union; tauto.
Qed.

Lemma pmap_keys_order {A} (m1 m2 : Pmap A) :
  keys m1 ≡ₚ keys m2 -> keys m1 = keys m2.
Proof.
Admitted.
