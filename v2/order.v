(* The order of a permutation group given a generating set. *)

From stdpp Require Import finite.
From permlib Require Import util perm.

Notation comp := (foldr (⋅) ∅).

Lemma comp_app w1 w2 :
  comp (w2 ++ w1) ≡ comp w2 ⋅ comp w1.
Proof.
induction w2; cbn; intros; symmetry.
apply (left_id ∅ (⋅)). rewrite <-(assoc (⋅)), IHw2; done.
Qed.

Theorem perm_order (π : perm) :
  ∃ k, comp (repeat π (S k)) ≡ ∅.
Proof.
pose (r := permutations (values π));
pose (n := S (length r));
pose (s := values ∘ comp ∘ repeat π <$> seq 1 n);
destruct (list_pigeonhole s r) as (i & j & ps & H1 & H2 & H3).
- unfold s, r; intros xs H; apply elem_of_list_fmap in H as (k & -> & H).
  apply elem_of_seq in H; destruct k; [lia|clear].
  unfold compose; apply permutations_Permutation.
  induction k; cbn in *.
  + rewrite <-?perm_Permutation, keys_perm_compose; done.
  + rewrite IHk, <-?perm_Permutation, keys_perm_compose with (τ:=_⋅_).
    rewrite list_union_sym, list_union_cancel. done.
    rewrite keys_perm_compose; set_solver. all: apply NoDup_keys.
- unfold s, n, r; rewrite fmap_length, seq_length; auto.
- unfold s, compose in H2, H3.
  exists (j - 1 - i)%nat; replace (S (j - 1 - i)) with (j - i)%nat by lia.
  apply list_lookup_fmap_inv in H2 as (i' & -> & Hi'), H3 as (j' & H2 & Hj');
  apply lookup_seq in Hi' as [-> _], Hj' as [-> _]; apply perm_eq_values in H2.
  apply group_compose_cancel with (z:=comp (repeat π (1 + i))).
  rewrite (left_id ∅ (⋅)), <-comp_app, <-repeat_app.
  replace (j - i + (1 + i))%nat with (1 + j)%nat by lia; done.
Qed.

Section Generating_set.

Variable gen : list perm.

Definition Generates (π : perm) :=
  ∃ w, w ⊆ gen ∧ π ≡ comp w.

Record Group_Order (ord : positive) := Group_Enumeration {
  enum : positive -> perm;
  enum_gen : ∀ i, i ≤ ord -> Generates (enum i);
  enum_inj : ∀ i j, i ≤ ord -> j ≤ ord -> enum i ≡ enum j -> i = j;
  enum_surj : ∀ π, Generates π -> ∃ i, i ≤ ord ∧ π ≡ enum i;
}.

Lemma generates_e :
  Generates ∅.
Proof.
exists []; split; [|done].
apply list_subseteq_nil.
Qed.

Lemma generates_generator σ :
  σ ∈ gen -> Generates σ.
Proof.
exists [σ]; split; cbn. set_solver.
symmetry; apply (right_id ∅ (⋅)).
Qed.

Lemma generates_compose τ π :
  Generates τ -> Generates π -> Generates (π⋅τ).
Proof.
intros [w_τ [H1 H2]] [w_π [H3 H4]]; exists (w_π ++ w_τ); split.
set_solver. rewrite comp_app, H2, H4; done.
Qed.

Lemma generates_inv π :
  Generates π -> Generates (inv π).
Proof.
intros [w [H1 H2]]; destruct (perm_order π) as [k H3]; cbn in H3.
exists (concat (repeat w k)); split.
- clear H2 H3; induction k; cbn; set_solver.
- assert (H4 : inv π ≡ comp (repeat π k)).
  + symmetry; rewrite <-(left_id ∅ (⋅)), <-(left_inv π) at 1.
    rewrite <-(assoc (⋅)), H3, (right_id ∅ (⋅)); done.
  + rewrite H4; clear H1 H3 H4; induction k; cbn in *. done.
    rewrite IHk; rewrite H2, comp_app; done.
Qed.

End Generating_set.

Lemma unit_group_order :
  Group_Order [] 1.
Proof.
exists (λ _, ∅); intros. apply generates_e. lia. destruct H as [w []].
apply list_nil_subseteq in H as ->; exists 1; done.
Qed.
