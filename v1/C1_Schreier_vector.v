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
  (λ σ_u, let σu := fst σ_u ∘ snd σ_u in (lookup ϕ σu⋅k ?? ident) ∘ σu)
  (list_prod gen (values V)).

(***
Theorems
*)

Hypothesis perms : Forall Perm gen.

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
destruct extend_loop as [V' new] eqn:E.
replace_fst V' new E; destruct new; [|apply IHn].
all: apply prop_extend_loop, H.
Qed.

Lemma prop_loop_le V try m n :
  P (loop V try m) -> m <= n -> P (loop V try n).
Proof.
revert V try n; induction m; simpl; intros.
apply prop_loop, H. destruct n; [easy|simpl].
destruct extend_loop as [V' new] eqn:E.
destruct new; [easy|]. apply IHm. easy. apply le_S_n, H0.
Qed.

End Generic.

Section Soundness.

(* The orbit permutations are valid. *)
Definition Sound (V : vector) :=
  ∀i π, lookup V i = Some π -> Generates gen π /\ π⋅k = i.

Lemma sound_extend π gen' V new :
  Generates gen π -> gen' ⊆ gen ->
  Sound V -> Sound (fst (extend π⋅k π gen' V new)).
Proof.
revert V new; simple_ind gen'.
apply incl_cons_inv in H0 as [].
destruct lookup; apply IHgen'; try easy.
intros j; rewrite lookup_insert; destruct (_ =? _) eqn:E.
convert_bool; subst; split; inv H3. apply generates_compose.
easy. apply generates_generator; easy. apply apply_compose.
apply H1.
Qed.

Lemma sound_extend_loop V try new :
  Sound V -> Sound (fst (extend_loop V try new)).
Proof.
revert V new; simple_ind try.
destruct (lookup V a) eqn:E.
destruct extend as [V' new'] eqn:E'.
replace_fst V' new' E'. all: apply IHtry; try easy.
apply H in E as []; subst. apply sound_extend; easy.
Qed.

Theorem sound_build bound :
  Sound (build bound).
Proof.
unfold build; apply prop_loop. apply sound_extend_loop.
intros i; rewrite lookup_insert; simpl.
destruct (k =? i) eqn:E; [convert_bool; subst; intros|easy].
inv H; split. apply generates_ident. easy.
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

Lemma lookup_extend j π gen' V new i τ :
  lookup V i = Some τ -> lookup (fst (extend j π gen' V new)) i = Some τ.
Proof.
revert V new; simple_ind gen'.
destruct (lookup V a⋅j) eqn:E; erewrite <-IHgen'; try easy.
rewrite lookup_insert; destruct (_ =? _)%positive eqn:E'; convert_bool.
rewrite E', H in E; easy. easy.
Qed.

Lemma lookup_extend_loop V try new i τ :
  lookup V i = Some τ -> lookup (fst (extend_loop V try new)) i = Some τ.
Proof.
revert V new; simple_ind try.
destruct (lookup V a) eqn:E. destruct extend as [V' new'] eqn:E'.
replace_fst V' new' E'. all: apply IHtry; try easy.
apply lookup_extend; easy.
Qed.

Lemma defined_extend i j π gen' V new :
  Defined V i -> Defined (fst (extend j π gen' V new)) i.
Proof.
destruct (lookup V i) eqn:E; [intros _|easy].
erewrite lookup_extend. easy. apply E.
Qed.

Lemma defined_extend_loop V try new i :
  Defined V i -> Defined (fst (extend_loop V try new)) i.
Proof.
destruct (lookup V i) eqn:E; [intros _|easy].
erewrite lookup_extend_loop. easy. apply E.
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
revert V new; simple_ind try. destruct (lookup V a) eqn:E.
destruct extend as [V' new'] eqn:E'. all: apply IHtry; try easy.
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
  destruct lookup eqn:E; eapply IHgen' in H; try easy; intros.
  + destruct (ffun_eq_dec a σ); subst. rewrite E; easy.
    apply H1. easy. intros []; easy.
  + destruct (ffun_eq_dec a σ); subst. rewrite lookup_insert_eq; easy.
    apply defined_before_insert, H1. easy. intros []; easy.
  + (* Here we show that the insertion produces a new intermediate vector. *)
    destruct H2. rewrite app_comm_cons in H2; apply Forall_app in H2. split.
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
destruct extend as [V'' new'] eqn:E'.
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
destruct extend_loop as [V' new] eqn:E. assert(Intermediate V' new).
eapply intermediate_extend_loop. apply E. rewrite app_nil_r; easy.
eapply defined_extend_loop in H1 as H3; rewrite E in H3; simpl in H3.
eapply not_new_extend_loop in H1 as H4; [rewrite E in H4; simpl in H4|easy].
destruct new as [|j new]. apply intermediate_finished; easy.
apply incl_cons_inv in H. simpl; apply IHw; try easy.
destruct H2 as [_ ?]; apply H2 in H3 as []; [easy|].
apply H3; easy.
Qed.

Theorem complete_build n :
  size (put k (union_range gen)) <= n -> Complete (build n).
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
  replace (length w') with (length (path w' k)) at 1.
  apply NoDup_incl_length. easy. apply path_range, H5.
  unfold path; rewrite map_length, seq_length; easy.
Qed.

Theorem lookup_ident n :
  lookup (build n) k = Some ident.
Proof.
unfold build; apply prop_loop.
intros; apply lookup_extend_loop; easy.
apply lookup_insert_eq.
Qed.

End Completeness.

Section Schreiers_lemma.

Variable V : vector.

Notation ϕ π := (lookup V π⋅k ?? ident).

Lemma lookup_mapval_inv π :
  lookup (mapval inv V) π⋅k ?? ident = inv (ϕ π).
Proof.
destruct (lookup V π⋅k) eqn:E.
erewrite lookup_mapval_some; easy.
rewrite lookup_mapval_none; easy.
Qed.

Theorem in_generators σ u :
  In σ gen -> In u (values V) ->
  let σu := σ ∘ u in let π := inv (ϕ σu) ∘ σu in In π (generators V).
Proof.
intros; apply in_map_iff; exists (σ, u); simpl; split.
rewrite lookup_mapval_inv; easy. apply in_prod; easy.
Qed.

Hypothesis sound : Sound V.

Lemma generates_vector_words w :
  In w (values V) -> Generates gen w.
Proof.
intros; apply in_values_lookup in H as [i ?].
apply sound in H; easy.
Qed.

Theorem in_generators_inv π :
  In π (generators V) -> ∃τ, Generates gen τ /\ π == inv (ϕ τ) ∘ τ.
Proof.
intros H; apply in_map_iff in H as [[σ u] []]; exists (σ ∘ u); split.
apply in_prod_iff in H0 as []; apply generates_compose.
apply generates_vector_words, H1. apply generates_generator; easy.
simpl in H; rewrite lookup_mapval_inv in H; rewrite H; easy.
Qed.

Lemma generates_vector_lookup π :
  Generates gen (ϕ π).
Proof.
destruct lookup eqn:E.
eapply sound, E. apply generates_ident.
Qed.

Hypothesis complete : Complete V.

Lemma vector_lookup_spec π :
  Generates gen π -> (ϕ π)⋅k = π⋅k.
Proof.
intros H; apply complete in H.
destruct (lookup V π⋅k) eqn:E; [|easy].
apply sound, E.
Qed.

Hypothesis k_ident : lookup V k = Some ident.

Lemma ident_in_vector :
  In ident (values V).
Proof.
eapply lookup_in_values, k_ident.
Qed.

Lemma vector_lookup_values π :
  In (ϕ π) (values V).
Proof.
destruct (lookup V π⋅k) eqn:E.
eapply lookup_in_values, E. apply ident_in_vector.
Qed.

Theorem generates_generators :
  Forall (Generates gen) (generators V).
Proof.
apply Forall_forall; intros.
apply in_generators_inv in H as [τ []].
eapply generates_subst; [apply H0|].
apply generates_compose; [easy|].
apply generates_inv; [easy|apply generates_vector_lookup].
Qed.

Theorem generators_stable π :
  Generates (generators V) π -> π⋅k = k.
Proof.
intros [w []]; rewrite H0; clear H0.
simple_ind w; rewrite apply_compose.
apply incl_cons_inv in H as []; apply IHw in H0; rewrite <-H0 at 2.
apply in_generators_inv in H as [τ []]; rewrite H1, apply_compose.
rewrite perm_inv_apply with (i:=k). easy. eapply generates_perm.
apply perms. apply generates_vector_lookup.
apply vector_lookup_spec, H.
Qed.

Definition translate :=
  fold_left (λ (u_w' : perm × list perm) σ,
    let (u, w') := u_w' in
    let σu := σ ∘ u in
    let u' := lookup V σu⋅k ?? ident in
    (u', w' ++ [(inv u' ∘ σu)])).

Theorem translate_fst_spec u u' w w' :
  In u (values V) -> w ⊆ gen ->
  fst (translate w (u, w')) = u' ->
  u'⋅k = apply' w u⋅k /\ In u' (values V).
Proof.
revert u w'; induction w; simpl; intros. subst; easy.
apply incl_cons_inv in H0. assert(Generates gen (a ∘ u)).
apply generates_compose. apply generates_vector_words, H.
apply generates_generator; easy.
apply IHw in H1 as []. split; [|easy].
rewrite H1, vector_lookup_spec, apply_compose; easy.
apply vector_lookup_values. easy.
Qed.

Lemma translate_subst_word u w w' w'' :
  fst (translate w (u, w')) = fst (translate w (u, w'')).
Proof.
revert u w' w''; simple_ind w; apply IHw.
Qed.

Lemma translate_shift_word u w w' :
  snd (translate w (u, w')) = w' ++ snd (translate w (u, [])).
Proof.
revert u w'; induction w; simpl; intros. rewrite app_nil_r; easy.
rewrite IHw with (w' := [_]), IHw, app_assoc; easy.
Qed.

Lemma translate_remove_word u u' w w' w'' :
  translate w (u, w') = (u', w' ++ w'') ->
  translate w (u, []) = (u', w'').
Proof.
intros; assert(snd (translate w (u, w')) = w' ++ w'') by (rewrite H; easy).
rewrite translate_shift_word in H0. apply app_inv_head in H0.
rewrite surjective_pairing at 1; rewrite H0.
erewrite translate_subst_word, H; easy.
Qed.

Theorem translate_snd_spec u u' w w' :
  translate w (u, []) = (u', w') ->
  u' ∘ compose' w' ∘ inv u == compose' w.
Proof.
revert u u' w'; induction w; simpl; intros.
inv H; simpl. admit.
assert(w' = snd (u', w')) by easy; rewrite <-H in H0.
rewrite translate_shift_word in H0; subst w'; simpl.
apply translate_remove_word, IHw in H; remember (snd (translate _ _)) as π.
Admitted.

Theorem generators_incl_translate_snd u w :
  In u (values V) -> w ⊆ gen ->
  snd (translate w (u, [])) ⊆ generators V.
Proof.
revert u; simple_ind w; rewrite translate_shift_word.
apply incl_cons_inv in H0 as []; apply incl_app.
intros i Hi; inv Hi; apply in_generators; easy.
apply IHw. apply vector_lookup_values. easy.
Qed.

Theorem generators_complete π :
  Generates gen π -> π⋅k = k -> Generates (generators V) π.
Proof.
intros [w []] ?; destruct (translate w (ident, [])) as [u' w'] eqn:E.
exists w'; split. replace_snd u' w' E; apply generators_incl_translate_snd.
apply ident_in_vector. easy. apply translate_snd_spec in E as ?; simpl in H2.
etransitivity; [apply H0|etransitivity; [symmetry; apply H2|]].
(* The crux: we can determine that u' = ident. *)
assert(fst (u', w') = u') by easy; rewrite <-E in H3.
apply translate_fst_spec in H3 as []; [|apply ident_in_vector|easy].
replace (ident⋅k) with k in H3 by easy.
rewrite <-apply_compose', <-H0, H1 in H3.
apply in_values_lookup in H4 as [i ?].
apply sound in H4 as H5; destruct H5.
rewrite H6 in H3; subst. rewrite k_ident in H4.
inv H4; rewrite leaf_compose; easy.
Qed.

Corollary generators_spec π :
  Generates (generators V) π <-> Generates gen π /\ π⋅k = k.
Proof.
repeat split; intros.
eapply generates_inclusion. apply generates_generators. apply H.
apply generators_stable, H. apply generators_complete; easy.
Qed.

End Schreiers_lemma.

End Vector.
End Schreier.
