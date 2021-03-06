(* Definition and manipulation of generator words. *)

From CGT Require Import A1_setup A2_lists B1_fmap B2_perm.
Require Import Lia.

(***
:: Words ::

We want to express permutations as words in an alphabet of generators. In this
file we implement two types of words: (1) Lists of permutations which are
contained in a list of generators. These words are used in proofs and use
left-to-right composition! (2) Lists of letters with positive indices. These
words are used for the strong generating set filling algorithm and use
right-to-left composition. The inverse of a generator is part of the alphabet
because inverting words is essential. For fast application of these words we
store generators and their inverses in a lookup map.
*)

(***
Global definitions.
*)

(* Letters for invertible words and fast operations. *)
Inductive letter :=
  | Forward (x : positive)
  | Inverse (x : positive).

Notation word := (list letter).

(* Apply a list of permutations to index i. *)
Notation apply' := (fold_left (λ i f, f⋅i)).

(* Compose a list of permutations. *)
Notation compose'' := (fold_right (λ σ π, π ∘ σ)).
Notation compose' := (compose'' ident).

Section Simple_words.

Theorem apply_compose' w i :
  (compose' w)⋅i = apply' w i.
Proof.
revert i; simple_ind w.
rewrite apply_compose, IHw; easy.
Qed.

Theorem compose''_compose' π w :
  compose'' π w == π ∘ compose' w.
Proof.
simple_ind w; intros i.
rewrite <-compose_assoc, ?apply_compose.
rewrite IHw, apply_compose; easy.
Qed.

(***
:: Bounded length of connecting paths ::

The orbit of k consists of all points that are reachable from k using a
generator. We can imagine all moving points (the objects that are permuted) as
nodes in a graph which are connected by permutations. An edge between two nodes
may be labelled with multiple permutations, and one permutation occurs at
multiple edges. Every word forms a path in this graph, connecting different
pairs of points. We show that the orbit of k is fully determined when all words
with length at most the number of points in the graph have been accounted for.
*)

Local Open Scope nat.

(* The points visited by word w starting at point i. *)
Definition path w i := map (λ n, apply' (firstn n w) i) (seq 1 (length w)).

Lemma apply'_range gen w i :
  w ⊆ gen -> apply' w i = i \/ ∃σ, In σ gen /\ In (apply' w i) (values σ).
Proof.
revert i; induction w; simpl; intros. left; easy.
destruct (IHw a⋅i). eapply incl_cons_inv, H.
destruct (Pos.eq_dec a⋅i i). left; congruence.
right; exists a; split. auto with datatypes.
rewrite H0; apply apply_in_values; easy.
right; easy.
Qed.

Theorem path_range gen w k :
  w ⊆ gen -> path w k ⊆ values (put k (union_range gen)).
Proof.
intros H i Hi. apply in_map_iff in Hi as [n []]; subst. apply in_seq in H1.
edestruct apply'_range with (w:=firstn n w). auto with datatypes.
rewrite H0; apply in_values_insert. eapply lookup_in_values.
destruct H0; eapply lookup_after_put, lookup_union_range.
apply a. apply H, a.
Qed.

Lemma remove_cycle w i j j0 j1 j2 :
  path w i = j0 ++ j :: j1 ++ j :: j2 ->
  ∃w', w' ⊆ w /\ length w' < length w /\ apply' w' i = apply' w i.
Proof.
pose(n0 := length j0);
pose(n1 := length j1);
pose(n2 := length j2).
unfold path; intros.
assert(length w = n0 + 1 + n1 + 1 + n2). {
  assert(E := wd (@length _) _ _ H).
  rewrite map_length, seq_length in E; rewrite E.
  repeat (rewrite app_length; simpl); lia. }
(* Cut the visited points list into parts. *)
rewrite H0, ?seq_app, ?map_app, <-?app_assoc in H.
replace (j0 ++ _) with (j0 ++ [j] ++ j1 ++ [j] ++ j2) in H by easy.
apply app_cut in H as [? H]. apply app_cut in H as [? H].
apply app_cut in H as [? H]. apply app_cut in H as [? H].
apply map_singleton_eq in H2, H4; clear H1 H3 H.
2-5: rewrite map_length, seq_length; easy.
(* Give the shortened word. *)
exists (firstn (1 + n0) w ++ skipn (1 + (n0 + 1 + n1)) w); repeat split.
auto with datatypes. simpl_list; lia.
rewrite fold_left_app, H2, <-H4.
rewrite <-fold_left_skipn; easy.
Qed.

(* Remove cycles from a connecting word. *)
Theorem short_connecting_word w i :
  ∃w', w' ⊆ w /\ NoDup (path w' i) /\ apply' w' i = apply' w i.
Proof.
revert w; apply lt_length_wf_ind; intros w IH.
destruct (nodup_dec _ Pos.eq_dec (path w i)).
exists w; easy. destruct e as [j0 [j [j1 []]]].
apply in_split in H0 as [j2 [j3 ?]]; subst.
apply remove_cycle in H as [w' [? []]].
apply IH in H0 as [w'' [? []]]; exists w''; repeat split.
eapply incl_tran; [apply H0|apply H]. apply H2. congruence.
Qed.

End Simple_words.

Section Fast_invertible_words.

Local Open Scope positive.

(* Compare two letters. *)
Definition eqb_letter (a b : letter) :=
  match a, b with
  | Forward i, Forward j => i =? j
  | Inverse j, Inverse i => i =? j
  | _, _ => false
  end.

(* Invert a letter. *)
Definition inv_letter (a : letter) :=
  match a with
  | Forward i => Inverse i
  | Inverse i => Forward i
  end.

(* Invert a word. *)
Definition inv_word (w : word) := rev (map inv_letter w).

(* Remove redundant permutations from a word. *)
Fixpoint reduce (stack w : word) :=
  match w with
  | [] => rev stack
  | a :: w' =>
    match stack with
    | [] => reduce [a] w'
    | b :: s =>
      if eqb_letter a (inv_letter b)
      then reduce s w'
      else reduce (a :: stack) w'
    end
  end.

(* Go to the next word given a reset index. *)
Fixpoint next_word (reset : positive) (w : word) :=
  match w with
  | [] => [Forward reset]
  | Forward 1 :: w' => Inverse reset :: w'
  | Forward i :: w' => Forward (Pos.pred i) :: w'
  | Inverse 1 :: w' => Forward reset :: next_word reset w'
  | Inverse i :: w' => Inverse (Pos.pred i) :: w'
  end.

(***
:: Word application ::

When building words we can compose the generators corresponding to each letter
to find the permutations they represent. But composition is expensive, and in
the SGS (strong generating set) building algorithm by Minkwitz we only need to
do specific lookups in the resulting permutations. I expect that the average
word length will be short enough such that composition does not have an
advantage over directly applying the generators one-by-one.
*)
Definition generators := fmap perm × fmap perm.

(* Apply a word to a number. *)
Fixpoint apply_word (gen : generators) (w : word) (i : positive) :=
  match w with
  | [] => i
  | Forward x :: w' => (lookup (fst gen) x ?? ident)⋅(apply_word gen w' i)
  | Inverse x :: w' => (lookup (snd gen) x ?? ident)⋅(apply_word gen w' i)
  end.

(* Build fast lookup map for a generating set. *)
Definition prepare_generators (gen : list perm) : generators :=
  fold_left (λ dst src, (
    insert (fst dst) (fst src) (snd src),
    insert (snd dst) (fst src) (inv (snd src))))
    (combine (map Pos.of_nat (seq 1 (length gen))) gen)
    (Leaf, Leaf).

(***
I find it inelegant to repeatedly produce natural numbers for list length
comparison, so I created these optimized functions.
*)

(* Optimized version of `length l <=? n`. *)
Fixpoint length_le_nat {X} (l : list X) n :=
  match l with
  | [] => true
  | _ :: l' =>
    match n with
    | O => false
    | S m => length_le_nat l' m
    end
  end.

(* Optimized version of `length l1 <=? length l2`. *)
Fixpoint length_le_length {X} (l1 l2 : list X) :=
  match l1 with
  | [] => true
  | _ :: l1' =>
    match l2 with
    | [] => false
    | _ :: l2' => length_le_length l1' l2'
    end
  end.

End Fast_invertible_words.
