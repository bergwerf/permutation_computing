(* A functional Schreier-vector to compute orbits. *)

From CGT Require Import A1_setup A2_lists B1_fmap B2_perm B3_word B4_group.

Module Schreier.
Section Vector.

Definition vector := fmap perm.

(* Add all numbers reachable from i. *)
Fixpoint extend (i : positive) (π : perm)
  (gen : list perm) (V : vector)
  (new : list positive) :=
  match gen with
  | [] => (V, new)
  | σ :: gen' =>
    let j := σ⋅i in
    match lookup V j with
    | Some _ => extend i π gen' V new
    | None => extend i π gen' (insert V j (σ ∘ π)) (j :: new)
    end
  end.

(* The generating set. *)
Variable gen : list perm.

(* Extend all numbers in the source list. *)
Fixpoint extend_loop (V : vector) (try new : list positive) :=
  match try with
  | [] => (V, new)
  | i :: try' =>
    match lookup V i with
    | None => extend_loop V try' new
    | Some π =>
      match extend i π gen V new with
      | (V', new') => extend_loop V' try' new'
      end
    end
  end.

(* Repeat orbit extension n times. *)
Fixpoint loop (V : vector) (try : list positive) (n : nat) :=
  match n with
  | O => V
  | S m =>
    match extend_loop V try [] with
    | (V', []) => V'
    | (V', new) => loop V' new m
    end
  end.

(* The stabilizer point. *)
Variable k : positive.

(* Build an orbit vector given an orbit size bound. *)
(* Note that it doesn't make a difference if the bound is bigger than needed. *)
Definition build (bound : nat) := loop (insert Leaf k ident) [k] bound.

(* The orbit given by they keys of the Schreier vector. *)
Definition orbit (V : vector) : list positive := map fst (entries V xH).

(* The subgroup generators according to Schreier's Lemma. *)
Definition generators (V : vector) : list perm :=
  let ϕ := mapval inv V in map
  (λ a_u, let au := fst a_u ∘ snd a_u in (lookup ϕ au⋅k ?? ident) ∘ au)
  (list_prod gen (values V)).

(***
Theorems
*)

Ltac replace_fst x y E := replace x with (fst (x, y)) by easy; rewrite <-E.
Ltac replace_snd x y E := replace y with (snd (x, y)) by easy; rewrite <-E.

Section Generic.

Open Scope nat.

Variable P : vector -> Prop.
Hypothesis prop_extend_loop :
  ∀V try new, P V -> P (fst (extend_loop V try new)).

Lemma prop_loop V try n :
  P V -> P (loop V try n).
Proof.
revert V try; simple_ind n.
destruct (extend_loop _) as [V' new] eqn:E.
replace_fst V' new E; destruct new; [|apply IHn].
all: apply prop_extend_loop, H.
Qed.

Lemma prop_loop_le V try m n :
  P (loop V try m) -> m <= n -> P (loop V try n).
Proof.
revert V try n; induction m; simpl; intros.
apply prop_loop, H. destruct n; [easy|simpl].
destruct (extend_loop _) as [V' new] eqn:E.
destruct new; [easy|]. apply IHm. easy. apply le_S_n, H0.
Qed.

End Generic.

Section Soundness.

(* The orbit permutations are valid. *)
Definition Sound (V : vector) := ∀i,
  match lookup V i with
  | Some π => Generates gen π /\ π⋅k = i
  | None => True
  end.

Lemma sound_extend π gen' V new :
  Generates gen π -> gen' ⊆ gen ->
  Sound V -> Sound (fst (extend π⋅k π gen' V new)).
Proof.
revert V new; simple_ind gen'.
apply incl_cons_inv in H0 as [].
destruct (lookup _); apply IHgen'; try easy.
intros j; rewrite lookup_insert.
destruct (_ =? _) eqn:E; [convert_bool; subst; split|apply H1].
apply compose_generator; easy. apply apply_compose.
Qed.

Lemma sound_extend_loop V try new :
  Sound V -> Sound (fst (extend_loop V try new)).
Proof.
revert V new; simple_ind try.
destruct (lookup V a) eqn:E.
destruct (extend _) as [V' new'] eqn:E'.
replace_fst V' new' E'. all: apply IHtry; try easy.
assert(Ha := H a); rewrite E in Ha; destruct Ha; subst.
apply sound_extend; easy.
Qed.

Theorem sound_build bound :
  Sound (build bound).
Proof.
unfold build; apply prop_loop. apply sound_extend_loop.
intros i. rewrite lookup_insert; simpl.
destruct (k =? i) eqn:E. convert_bool; subst.
split. exists []; simpl; easy. easy. easy.
Qed.

End Soundness.

Section Completeness.

Local Open Scope nat.

(* The vector contains the full orbit. *)
Definition Complete (V : vector) := ∀π, Generates gen π -> Defined V π⋅k.

(* The vector and the new points are an intermediary result. *)
Definition Intermediate (V : vector) new :=
  Forall (λ i, Defined V i) new /\
  ∀i, Defined V i -> In i new \/ ∀σ, In σ gen -> Defined V σ⋅i.

Lemma defined_extend i j π gen' V new :
  Defined V i -> gen' ⊆ gen -> Defined (fst (extend j π gen' V new)) i.
Proof.
revert V new; simple_ind gen'. apply incl_cons_inv in H0.
destruct (lookup V a⋅j) eqn:E; apply IHgen'; try easy.
apply defined_before_insert, H.
Qed.

Lemma defined_extend_loop V try new i :
  Defined V i -> Defined (fst (extend_loop V try new)) i.
Proof.
revert V new; simple_ind try.
destruct (lookup V a) eqn:E.
destruct (extend _) as [V' new'] eqn:E'.
replace_fst V' new' E'. all: apply IHtry; try easy.
apply defined_extend; easy.
Qed.

Lemma not_new_extend i j π gen' V new :
  Defined V i -> ¬In i new -> ¬In i (snd (extend j π gen' V new)).
Proof.
revert V new; simple_ind gen'.
destruct (lookup V a⋅j) eqn:E; apply IHgen'; try easy.
apply defined_before_insert, H. intros []; [subst|easy].
rewrite E in H; easy.
Qed.

Lemma not_new_extend_loop V try new i :
  Defined V i -> ¬In i new -> ¬In i (snd (extend_loop V try new)).
Proof.
revert V new; simple_ind try.
destruct (lookup V a) eqn:E.
destruct (extend _) as [V' new'] eqn:E'.
all: apply IHtry; try easy.
replace_fst V' new' E'; apply defined_extend; easy.
replace_snd V' new' E'; apply not_new_extend; easy.
Qed.

Lemma intermediate_extend try i π gen' V new V' new' :
  extend i π gen' V new = (V', new') ->
  gen' ⊆ gen -> (∀σ, In σ gen -> ¬In σ gen' -> Defined V σ⋅i) ->
  Intermediate V (i :: try ++ new) -> Intermediate V' (try ++ new').
Proof.
revert V new; induction gen'; simpl; intros.
- inv H; destruct H2. split. inv H. intros.
  apply H2 in H3 as []. inv H3.
  right; intros; apply H1; easy.
  left; easy. right; easy.
- apply incl_cons_inv in H0.
  destruct (lookup _) eqn:E; eapply IHgen' in H; try easy; intros.
  + destruct (ffun_eq_dec a σ); subst. rewrite E; easy.
    apply H1. easy. intros []; easy.
  + destruct (ffun_eq_dec a σ); subst. rewrite lookup_insert_eq; easy.
    apply defined_before_insert, H1. easy. intros []; easy.
  + destruct H2. rewrite app_comm_cons in H2; apply Forall_app in H2. split.
    * apply Forall_app with (l1:=i :: try); split.
      2: apply Forall_cons. 2: rewrite lookup_insert_eq; easy.
      all: eapply Forall_impl; [|apply H2].
      all: intros; apply defined_before_insert; easy.
    * intros. rewrite lookup_insert in H4.
      destruct (_ =? _)%positive eqn:E'; convert_bool; subst.
      left; auto with datatypes. apply H3 in H4 as [].
      left; rewrite app_comm_cons; apply in_app_comm, in_cons, in_app_comm, H4.
      right; intros; apply defined_before_insert, H4, H5.
Qed.

Lemma intermediate_extend_loop V try new V' try' :
  extend_loop V try new = (V', try') ->
  Intermediate V (try ++ new) -> Intermediate V' try'.
Proof.
revert V new; induction try; simpl; intros. inv H.
assert(Defined V a) by (destruct H0; inv H0).
destruct (lookup V a) eqn:E; [|easy].
destruct (extend _) as [V'' new'] eqn:E'.
eapply IHtry. apply H. eapply intermediate_extend.
apply E'. all: easy.
Qed.

Lemma intermediate_finished V w i :
  Intermediate V [] -> Defined V i -> w ⊆ gen -> Defined V (apply' w i).
Proof.
intros [_ H]; revert i; simple_ind w.
apply incl_cons_inv in H1 as []. apply IHw.
apply H in H0 as []; [easy|apply H0, H1]. easy.
Qed.

Lemma complete_loop V try i w :
  w ⊆ gen -> Intermediate V try -> Defined V i ->
  Defined (loop V try (length w)) (apply' w i).
Proof.
revert V try i; induction w as [|σ w]; [easy|intros; simpl loop].
destruct (extend_loop _) as [V' new] eqn:E. assert(Intermediate V' new).
eapply intermediate_extend_loop. apply E. rewrite app_nil_r; easy.
eapply defined_extend_loop in H1 as H3; rewrite E in H3; simpl in H3.
eapply not_new_extend_loop in H1 as H4; [rewrite E in H4; simpl in H4|easy].
destruct new as [|j new]. apply intermediate_finished; easy.
apply incl_cons_inv in H. simpl; apply IHw; try easy.
destruct H2 as [_ ?]; apply H2 in H3 as []; [easy|].
apply H3; easy.
Qed.

Theorem complete_build n :
  size (put (union_range gen) k) <= n -> Complete (build n).
Proof.
intros H π [w []]; unfold build.
destruct (short_connecting_word w k) as [w' [? []]].
assert(w' ⊆ gen) by eauto with datatypes.
rewrite H1, apply_compose', <-H4. eapply prop_loop_le.
intros; apply defined_extend_loop; easy.
apply complete_loop. easy.
- split. apply Forall_cons. rewrite lookup_insert_eq; easy. auto.
  intros. rewrite lookup_insert in H6.
  destruct (k =? i)%positive eqn:E; [|easy].
  convert_bool; subst; left; apply in_eq.
- rewrite lookup_insert_eq; easy.
- etransitivity; [|apply H]. rewrite size_eq_length_values.
  replace (length w') with (length (visited_points w' k)) at 1.
  apply NoDup_incl_length. easy. apply visited_points_range, H5.
  unfold visited_points; rewrite map_length, seq_length; easy.
Qed.

End Completeness.

Section Schreiers_lemma.

Variable V : vector.
Hypothesis sound : Sound V.
Hypothesis complete : Complete V.

Theorem generators_spec π :
  Generates gen π /\ π⋅k = k <-> Generates (generators V) π.
Proof.
Admitted.

End Schreiers_lemma.

End Vector.
End Schreier.
