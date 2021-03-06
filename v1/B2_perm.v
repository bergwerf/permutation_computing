(* Permutations as unbalanced binary trees (fmap). *)

From CGT Require Import A1_setup B1_fmap.

(***
:: Permutations ::

We use radix-2 trees (fmap) to store permutations. Of course not all finite maps
represent a permutation. Ways to describe a valid permutation include:
- A permutation is a function from a set to itself.
- A permutation is a composition of transpositions.
- A permutation is a bijective function.
*)

Definition perm := ffun.
Definition ident : ffun := Leaf.
Definition Perm π := Forall (λ i, Defined π i) (values π).

Theorem perm_ident :
  Perm ident.
Proof.
apply Forall_nil.
Qed.

Theorem perm_subst π τ :
  π == τ -> Perm τ -> Perm π.
Proof.
intros; apply Forall_forall; intros j ?.
apply in_values_lookup in H1 as [i ?].
destruct (Pos.eq_dec j i); subst. rewrite H1; easy.
assert(π⋅i = j). unfold apply; rewrite H1; easy.
rewrite H in H2; subst; apply apply_in_values in n.
eapply Forall_forall in n; [|apply H0]; simpl in n.
(* I think we first have to show that a Perm is bijective. *)
Admitted.

Theorem perm_compose π τ :
  Perm π -> Perm τ -> Perm (π ∘ τ).
Proof.
Admitted.

Theorem perm_inv π :
  Perm π -> Perm (inv π).
Proof.
Admitted.

Theorem perm_inv_apply π i j :
  Perm π -> π⋅i = j -> (inv π)⋅j = i.
Proof.
Admitted.

Theorem perm_inv_ident π :
  Perm π -> inv π ∘ π == ident.
Proof.
Admitted.

Theorem perm_order π :
  Perm π -> ∃n, iter n (λ τ, π ∘ τ) π == ident.
Proof.
Admitted.

(***
Build a permutation from a list.
*)
Definition create_perm (l : list positive) :=
  fold_left (λ π ij, match ij with (i, j) => insert π i j end)
    (combine (map Pos.of_nat (seq 1 (length l))) l) Leaf.

(***
:: Cycle notation ::

Permutations are often written as compositions of cycles. For example the cycle
`(1 3 2)` represents the function {⟨1, 3⟩, ⟨3, 2⟩, ⟨2, 1⟩}. We will also support
input and output of such cycles as lists of numbers. To make the implementation
simpler we require that the start of the cycle is repeated at the end. For
example: `(1 3 2) = [1; 3; 2; 1]`. We use such a list as a linear lookup list.
Because it is more natural for left-to-right readers we compose cycles left to
right.
*)
Module Cycles.

Definition cycle := list positive.

Fixpoint next (c : cycle) (i : positive) :=
  match c with
  | [] => i
  | [_] => i
  | i' :: (j :: _) as c' => if i =? i' then j else next c' i
  end.

(***
Convert permutation map to cycle list.
*)

Fixpoint push (cs : list (positive × cycle × positive))
  (d0 : positive) (d : cycle) (dn : positive) :=
  match cs with
  | [] => [(d0, d, dn)]
  | (c0, c, cn) :: cs' =>
    if dn =? c0
    then push cs' d0 (d ++ [dn] ++ c) cn
    else if d0 =? cn
    then push cs' c0 (c ++ [d0] ++ d) dn
    else (c0, c, cn) :: push cs' d0 d dn
  end.

Definition unpack (π : perm) : list cycle := map
  (λ ct, match ct with (c0, c, cn) => c0 :: c ++ [cn] end) (fold_left
  (λ cs m, match m with (i, j) => if i =? j then cs else push cs i [] j end)
  (entries π xH) []).

(***
Convert cycle list to permutation map.
*)

Fixpoint render (π : perm) (c : cycle) :=
  match c with
  | [] => π
  | [_] => π
  | i :: (j :: _) as c' => insert (render π c') i j
  end.

Definition pack (cs : list cycle) : perm :=
  fold_left (λ σ πi, πi ∘ σ) (map (render ident) cs) ident.

(***
Theorems
*)

Lemma next_head c0 c1 c :
next (c0 :: c1 :: c) c0 = c1.
Proof.
simpl; rewrite Pos.eqb_refl; reflexivity.
Qed.

Lemma next_tail c0 c1 c i :
  i =? c0 = false -> next (c0 :: c1 :: c) i = next (c1 :: c) i.
Proof.
simpl; intros; rewrite H; reflexivity.
Qed.

Lemma render_head π c0 c1 c :
  render π (c0 :: c1 :: c) = insert (render π (c1 :: c)) c0 c1.
Proof.
simpl; destruct c; reflexivity.
Qed.

Theorem apply_render π c i :
  next c i ≠ i -> (render π c)⋅i = next c i.
Proof.
induction c as [|c0 c]; intros. easy.
destruct c as [|c1 c]. easy. rewrite render_head.
destruct (i =? c0) eqn:E.
- apply Pos.eqb_eq in E; subst.
  rewrite next_head; apply apply_insert.
- rewrite next_tail in *; try apply E.
  unfold apply in *; rewrite lookup_insert.
  rewrite Pos.eqb_sym, E, IHc; easy.
Qed.

End Cycles.
