Require Import String ZArith.
Require Import Sail2_state_monad Sail2_prompt Sail2_state Sail2_state_monad_lemmas.
Require Import Sail2_state_lemmas.

(*adhoc_overloading
  Monad_Syntax.bind State_monad.bindS*)

(*section \<open>Hoare logic for the state, exception and nondeterminism monad\<close>

subsection \<open>Hoare triples\<close>
*)
Definition predS regs := sequential_state regs -> Prop.

Definition PrePost {Regs A E} (P : predS Regs) (f : monadS Regs A E) (Q : result A E -> predS Regs) : Prop :=
 (*"\<lbrace>_\<rbrace> _ \<lbrace>_\<rbrace>"*)
  forall s, P s -> (forall r s', List.In (r, s') (f s) -> Q r s').

Notation "{{ P }} m {{ Q }}" := (PrePost P m Q).

(*
lemma PrePostI:
  assumes "\<And>s r s'. P s \<Longrightarrow> (r, s') \<in> f s \<Longrightarrow> Q r s'"
  shows "PrePost P f Q"
  using assms unfolding PrePost_def by auto

lemma PrePost_elim:
  assumes "PrePost P f Q" and "P s" and "(r, s') \<in> f s"
  obtains "Q r s'"
  using assms by (fastforce simp: PrePost_def)
*)
Lemma PrePost_consequence Regs X E (A P : predS Regs) (f : monadS Regs X E) (B Q : result X E -> predS Regs) :
  PrePost A f B ->
  (forall s, P s -> A s) ->
  (forall v s, B v s -> Q v s) ->
  PrePost P f Q.
intros Triple PA BQ.
intros s Pre r s' IN.
specialize (Triple s).
auto.
Qed.

Lemma PrePost_strengthen_pre Regs X E (A B : predS Regs) (f : monadS Regs X E) (C : result X E -> predS Regs) :
  PrePost A f C ->
  (forall s, B s -> A s) ->
  PrePost B f C.
eauto using PrePost_consequence.
Qed.

Lemma PrePost_weaken_post Regs X E (A : predS Regs) (f : monadS Regs X E) (B C : result X E -> predS Regs) :
  PrePost A f B ->
  (forall v s, B v s -> C v s) ->
  PrePost A f C.
eauto using PrePost_consequence.
Qed.

Lemma PrePost_True_post (*[PrePost_atomI, intro, simp]:*) Regs A E (P : predS Regs) (m : monadS Regs A E) :
  PrePost P m (fun _ _ => True).
unfold PrePost. auto.
Qed.

Lemma PrePost_any Regs A E (m : monadS Regs A E) (Q : result A E -> predS Regs) :
  PrePost (fun s => forall r s', List.In (r, s') (m s) -> Q r s') m Q.
unfold PrePost. auto.
Qed.

Lemma PrePost_returnS (*[intro, PrePost_atomI]:*) Regs A E  (P : result A E -> predS Regs) (x : A) :
  PrePost (P (Value x)) (returnS x) P.
unfold PrePost, returnS.
intros s p r s' IN.
simpl in IN.
destruct IN as [[=] | []].
subst; auto.
Qed.

Lemma PrePost_bindS (*[intro, PrePost_compositeI]:*) Regs A B E (m : monadS Regs A E) (f : A -> monadS Regs B E) (P : predS Regs) (Q : result B E -> predS Regs) (R : A -> predS Regs) :
  (forall s a s', List.In (Value a, s') (m s) -> PrePost (R a) (f a) Q) ->
  (PrePost P m (fun r => match r with Value a => R a | Ex e => Q (Ex e) end)) ->
  PrePost P (bindS m f) Q.
intros F M s Pre r s' IN.
destruct (bindS_cases IN) as [(a & a' & s'' & [= ->] & IN' & IN'') | [(e & [= ->] & IN') | (e & a & s'' & [= ->] & IN' & IN'')]].
* eapply F. apply IN'. specialize (M s Pre (Value a') s'' IN'). apply M. assumption.
* specialize (M _ Pre _ _ IN'). apply M.
* specialize (M _ Pre _ _ IN'). simpl in M. eapply F; eauto.
Qed.

Lemma PrePost_bindS_ignore Regs A B E (m : monadS Regs A E) (f : monadS Regs B E) (P : predS Regs) (Q : result B E -> predS Regs) (R : predS Regs) :
  PrePost R f Q ->
  PrePost P m (fun r => match r with Value a => R | Ex e => Q (Ex e) end) ->
  PrePost P (bindS m (fun _ => f)) Q.
intros F M.
eapply PrePost_bindS; eauto.
* intros. apply F.
* apply M.
Qed.

Lemma PrePost_bindS_unit Regs B E (m : monadS Regs unit E) (f : unit -> monadS Regs B E) P Q R :
  PrePost R (f tt) Q ->
  PrePost P m (fun r => match r with Value a => R | Ex e => Q (Ex e) end) ->
  PrePost P (bindS m f) Q.
intros F M.
eapply PrePost_bindS with (R := fun _ => R).
* intros. destruct a. apply F.
* apply M.
Qed.

Lemma PrePost_readS (*[intro, PrePost_atomI]:*) Regs A E (P : result A E -> predS Regs) f :
  PrePost (fun s => P (Value (f s)) s) (readS f) P.
unfold PrePost, readS, returnS.
intros s Pre r s' [H | []].
inversion H; subst.
assumption.
Qed.

Lemma PrePost_updateS (*[intro, PrePost_atomI]:*) Regs E (P : result unit E -> predS Regs) f :
  PrePost (fun s => P (Value tt) (f s)) (updateS f) P.
unfold PrePost, readS, returnS.
intros s Pre r s' [H | []].
inversion H; subst.
assumption.
Qed.

Lemma PrePost_if Regs A E b (f g : monadS Regs A E) P Q :
  (b = true  -> PrePost P f Q) ->
  (b = false -> PrePost P g Q) ->
  PrePost P (if b then f else g) Q.
intros T F.
destruct b; auto.
Qed.

Lemma PrePost_if_branch (*[PrePost_compositeI]:*) Regs A E b (f g : monadS Regs A E) Pf Pg Q :
  (b = true  -> PrePost Pf f Q) ->
  (b = false -> PrePost Pg g Q) ->
  PrePost (if b then Pf else Pg) (if b then f else g) Q.
destruct b; auto.
Qed.

Lemma PrePost_if_then Regs A E b (f g : monadS Regs A E) P Q :
  b = true ->
  PrePost P f Q ->
  PrePost P (if b then f else g) Q.
intros; subst; auto.
Qed.

Lemma PrePost_if_else Regs A E b (f g : monadS Regs A E) P Q :
  b = false ->
  PrePost P g Q ->
  PrePost P (if b then f else g) Q.
intros; subst; auto.
Qed.

Lemma PrePost_prod_cases (*[PrePost_compositeI]:*) Regs A B E (f : A -> B -> monadS Regs A E) P Q x :
  PrePost P (f (fst x) (snd x)) Q ->
  PrePost P (match x with (a, b) => f a b end) Q.
destruct x; auto.
Qed.

Lemma PrePost_option_cases (*[PrePost_compositeI]:*) Regs A B E x (s : A -> monadS Regs B E) n PS PN Q :
  (forall a, PrePost (PS a) (s a) Q) ->
  PrePost PN n Q ->
  PrePost (match x with Some a => PS a | None => PN end) (match x with Some a => s a | None => n end) Q.
destruct x; auto.
Qed.

Lemma PrePost_let (*[intro, PrePost_compositeI]:*) Regs A B E y (m : A -> monadS Regs B E) P Q :
  PrePost P (m y) Q ->
  PrePost P (let x := y in m x) Q.
auto.
Qed.

Lemma PrePost_and_boolS (*[PrePost_compositeI]:*) Regs E (l r : monadS Regs bool E) P Q R :
  PrePost R r Q ->
  PrePost P l (fun r => match r with Value true => R | _ => Q r end) ->
  PrePost P (and_boolS l r) Q.
intros Hr Hl.
unfold and_boolS.
eapply PrePost_bindS.
2: { instantiate (1 := fun a => if a then R else Q (Value false)).
     eapply PrePost_weaken_post.
     apply Hl.
     intros [[|] | ] s H; auto. }
* intros. destruct a; eauto.
  apply PrePost_returnS.
Qed.

Lemma PrePost_or_boolS (*[PrePost_compositeI]:*) Regs E (l r : monadS Regs bool E) P Q R :
  PrePost R r Q ->
  PrePost P l (fun r => match r with Value false => R | _ => Q r end) ->
  PrePost P (or_boolS l r) Q.
intros Hr Hl.
unfold or_boolS.
eapply PrePost_bindS.
* intros.
  instantiate (1 := fun a => if a then Q (Value true) else R).
  destruct a; eauto.
  apply PrePost_returnS.
* eapply PrePost_weaken_post.
  apply Hl.
  intros [[|] | ] s H; auto.
Qed.

Lemma PrePost_failS (*[intro, PrePost_atomI]:*) Regs A E msg (Q : result A E -> predS Regs) :
  PrePost (Q (Ex (Failure msg))) (failS msg) Q.
intros s Pre r s' [[= <- <-] | []].
assumption.
Qed.

Lemma PrePost_assert_expS (*[intro, PrePost_atomI]:*) Regs E (c : bool) m (P : result unit E -> predS Regs) :
  PrePost (if c then P (Value tt) else P (Ex (Failure m))) (assert_expS c m) P.
destruct c; simpl.
* apply PrePost_returnS.
* apply PrePost_failS. 
Qed.

Lemma PrePost_chooseS (*[intro, PrePost_atomI]:*) Regs A E xs (Q : result A E -> predS Regs) :
  PrePost (fun s => forall x, List.In x xs -> Q (Value x) s) (chooseS xs) Q.
unfold PrePost, chooseS.
intros s IN r s' IN'.
apply List.in_map_iff in IN'.
destruct IN' as (x & [= <- <-] & IN').
auto.
Qed.

Lemma case_result_combine (*[simp]:*) A E X r (Q : result A E -> X) :
  (match r with Value a => Q (Value a) | Ex e => Q (Ex e) end) = Q r.
destruct r; auto.
Qed.

Lemma PrePost_foreachS_Nil (*[intro, simp, PrePost_atomI]:*) Regs A Vars E vars body (Q : result Vars E -> predS Regs) :
  PrePost (Q (Value vars)) (foreachS (A := A) nil vars body) Q.
simpl. apply PrePost_returnS.
Qed.

Lemma PrePost_foreachS_Cons Regs A Vars E (x : A) xs vars body (Q : result Vars E -> predS Regs) :
  (forall s vars' s', List.In (Value vars', s') (body x vars s) -> PrePost (Q (Value vars')) (foreachS xs vars' body) Q) ->
  PrePost (Q (Value vars)) (body x vars) Q ->
  PrePost (Q (Value vars)) (foreachS (x :: xs) vars body) Q.
intros XS X.
simpl.
eapply PrePost_bindS.
* apply XS.
* apply PrePost_weaken_post with (B := Q).
  assumption.
  intros; rewrite case_result_combine.
  assumption.
Qed.

Lemma PrePost_foreachS_invariant Regs A Vars E (xs : list A) vars body (Q : result Vars E -> predS Regs) :
  (forall x vars, List.In x xs -> PrePost (Q (Value vars)) (body x vars) Q) ->
  PrePost (Q (Value vars)) (foreachS xs vars body) Q.
revert vars.
induction xs.
* intros. apply PrePost_foreachS_Nil.
* intros. apply PrePost_foreachS_Cons.
  + auto with datatypes.
  + apply H. auto with datatypes.
Qed.

(*subsection \<open>Hoare quadruples\<close>

text \<open>It is often convenient to treat the exception case separately.  For this purpose, we use
a Hoare logic similar to the one used in [1]. It features not only Hoare triples, but also quadruples
with two postconditions: one for the case where the computation succeeds, and one for the case where
there is an exception.

[1] D. Cock, G. Klein, and T. Sewell, ‘Secure Microkernels, State Monads and Scalable Refinement’,
in Theorem Proving in Higher Order Logics, 2008, pp. 167–182.\<close>
*)
Definition PrePostE {Regs A Ety} (P : predS Regs) (f : monadS Regs A Ety) (Q : A -> predS Regs) (E : ex Ety -> predS Regs) : Prop :=
(* ("\<lbrace>_\<rbrace> _ \<lbrace>_ \<bar> _\<rbrace>")*)
  PrePost P f (fun v => match v with Value a => Q a | Ex e => E e end).

Notation "{{ P }} m {{ Q | X }}" := (PrePostE P m Q X).

(*lemmas PrePost_defs = PrePost_def PrePostE_def*)

Lemma PrePostE_I (*[case_names Val Err]:*) Regs A Ety (P : predS Regs) f (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  (forall s a s', P s -> List.In (Value a, s') (f s) -> Q a s') ->
  (forall s e s', P s -> List.In (Ex e, s') (f s) -> E e s') ->
  PrePostE P f Q E.
intros. unfold PrePostE.
unfold PrePost.
intros s Pre [a | e] s' IN; eauto.
Qed.

Lemma PrePostE_PrePost Regs A Ety P m (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePost P m (fun v => match v with Value a => Q a | Ex e => E e end) ->
  PrePostE P m Q E.
auto.
Qed.

Lemma PrePostE_elim Regs A Ety P f r s s' (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE P f Q E ->
  P s ->
  List.In (r, s') (f s) ->
  (exists v, r = Value v /\ Q v s') \/
  (exists e, r = Ex e /\ E e s').
intros PP Pre IN.
specialize (PP _ Pre _ _ IN).
destruct r; eauto.
Qed.

Lemma PrePostE_consequence Regs Aty Ety (P : predS Regs) f A B C (Q : Aty -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE A f B C ->
  (forall s, P s -> A s) ->
  (forall v s, B v s -> Q v s) ->
  (forall e s, C e s -> E e s) ->
  PrePostE P f Q E.
intros PP PA BQ CE.
intros s Pre [a | e] s' IN.
* apply BQ. specialize (PP _ (PA _ Pre) _ _ IN).
  apply PP.
* apply CE. specialize (PP _ (PA _ Pre) _ _ IN).
  apply PP.
Qed.

Lemma PrePostE_strengthen_pre Regs Aty Ety (P : predS Regs) f R (Q : Aty -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE R f Q E ->
  (forall s, P s -> R s) ->
  PrePostE P f Q E.
intros PP PR.
eapply PrePostE_consequence; eauto.
Qed.

Lemma PrePostE_weaken_post Regs Aty Ety (A : predS Regs) f (B C : Aty -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE A f B E ->
  (forall v s, B v s -> C v s) ->
  PrePostE A f C E.
intros PP BC.
eauto using PrePostE_consequence.
Qed.

Lemma PrePostE_weaken_Epost Regs Aty Ety (A : predS Regs) f (B : Aty -> predS Regs) (E F : ex Ety -> predS Regs) :
  PrePostE A f B E ->
  (forall v s, E v s -> F v s) ->
  PrePostE A f B F.
intros PP EF.
eauto using PrePostE_consequence.
Qed.
(*named_theorems PrePostE_compositeI
named_theorems PrePostE_atomI*)

Lemma PrePostE_conj_conds Regs Aty Ety (P1 P2 : predS Regs) m (Q1 Q2 : Aty -> predS Regs) (E1 E2 : ex Ety -> predS Regs) :
  PrePostE P1 m Q1 E1 ->
  PrePostE P2 m Q2 E2 ->
  PrePostE (fun s => P1 s /\ P2 s) m (fun r s => Q1 r s /\ Q2 r s) (fun e s => E1 e s /\ E2 e s).
intros H1 H2.
apply PrePostE_I.
* intros s a s' [p1 p2] IN.
  specialize (H1 _ p1 _ _ IN).
  specialize (H2 _ p2 _ _ IN).
  simpl in *.
  auto.
* intros s a s' [p1 p2] IN.
  specialize (H1 _ p1 _ _ IN).
  specialize (H2 _ p2 _ _ IN).
  simpl in *.
  auto.
Qed.

(*lemmas PrePostE_conj_conds_consequence = PrePostE_conj_conds[THEN PrePostE_consequence]*)

Lemma PrePostE_post_mp Regs Aty Ety (P : predS Regs) m (Q Q' : Aty -> predS Regs) (E: ex Ety -> predS Regs) :
  PrePostE P m Q' E ->
  PrePostE P m (fun r s => Q' r s -> Q r s) E ->
  PrePostE P m Q E.
intros H1 H2.
eapply PrePostE_conj_conds in H1. 2: apply H2.
eapply PrePostE_consequence. apply H1. all: simpl; intuition.
Qed.

Lemma PrePostE_cong Regs Aty Ety (P1 P2 : predS Regs) m1 m2 (Q1 Q2 : Aty -> predS Regs) (E1 E2 : ex Ety -> predS Regs) :
  (forall s, P1 s <-> P2 s) ->
  (forall s, P1 s -> m1 s = m2 s) ->
  (forall r s, Q1 r s <-> Q2 r s) ->
  (forall e s, E1 e s <-> E2 e s) ->
  PrePostE P1 m1 Q1 E1 <-> PrePostE P2 m2 Q2 E2.
intros P12 m12 Q12 E12.
unfold PrePostE, PrePost.
split.
* intros. apply P12 in H0. rewrite <- m12 in H1; auto. specialize (H _ H0 _ _ H1).
  destruct r; [ apply Q12 | apply E12]; auto.
* intros. rewrite m12 in H1; auto. apply P12 in H0. specialize (H _ H0 _ _ H1).
  destruct r; [ apply Q12 | apply E12]; auto.
Qed.

Lemma PrePostE_True_post (*[PrePostE_atomI, intro, simp]:*) Regs A E P (m : monadS Regs A E) :
  PrePostE P m (fun _ _ => True) (fun _ _ => True).
intros s Pre [a | e]; auto.
Qed.

Lemma PrePostE_any Regs A Ety m (Q : result A Ety -> predS Regs) E :
  PrePostE (Ety := Ety) (fun s => forall r s', List.In (r, s') (m s) -> match r with Value a => Q a s' | Ex e => E e s' end) m Q E.
apply PrePostE_I.
intros. apply (H (Value a)); auto.
intros. apply (H (Ex e)); auto.
Qed.

Lemma PrePostE_returnS (*[PrePostE_atomI, intro, simp]:*) Regs A E P (x : A) (Q : ex E -> predS Regs) :
  PrePostE (P x) (returnS x) P Q.
unfold PrePostE, PrePost.
intros s Pre r s' [[= <- <-] | []].
assumption.
Qed.

Lemma PrePostE_bindS (*[intro, PrePostE_compositeI]:*) Regs A B Ety P m (f : A -> monadS Regs B Ety) Q R E :
  (forall s a s', List.In (Value a, s') (m s) -> PrePostE (R a) (f a) Q E) ->
  PrePostE P m R E ->
  PrePostE P (bindS m f) Q E.
intros.
unfold PrePostE in *.
eauto using PrePost_bindS.
Qed.

Lemma PrePostE_bindS_ignore Regs A B Ety (P : predS Regs) (m : monadS Regs A Ety) (f : monadS Regs B Ety) R Q E :
  PrePostE R f Q E ->
  PrePostE P m (fun _ => R) E ->
  PrePostE P (bindS m (fun _ => f)) Q E.
apply PrePost_bindS_ignore.
Qed.

Lemma PrePostE_bindS_unit Regs A Ety (P : predS Regs) (m : monadS Regs unit Ety) (f : unit -> monadS Regs A Ety) Q R E :
  PrePostE R (f tt) Q E ->
  PrePostE P m (fun _ => R) E ->
  PrePostE P (bindS m f) Q E.
apply PrePost_bindS_unit.
Qed.

Lemma PrePostE_readS (*[PrePostE_atomI, intro]:*) Regs A Ety (P : predS Regs) f (Q : result A Ety -> predS Regs) E :
  PrePostE (Ety := Ety) (fun s => Q (f s) s) (readS f) Q E.
unfold PrePostE, PrePost, readS.
intros s Pre [a | e] s' [[= <- <-] | []].
assumption.
Qed.

Lemma PrePostE_updateS (*[PrePostE_atomI, intro]:*) Regs Ety f (Q : unit -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (fun s => Q tt (f s)) (updateS f) Q E.
intros s Pre [a | e] s' [[= <- <-] | []].
assumption.
Qed.

Lemma PrePostE_if_branch (*[PrePostE_compositeI]:*) Regs A Ety (b : bool) (f g : monadS Regs A Ety) Pf Pg Q E :
  (b = true  -> PrePostE Pf f Q E) ->
  (b = false -> PrePostE Pg g Q E) ->
  PrePostE (if b then Pf else Pg) (if b then f else g) Q E.
destruct b; auto.
Qed.

Lemma PrePostE_if Regs A Ety (b : bool) (f g : monadS Regs A Ety) P Q E :
  (b = true  -> PrePostE P f Q E) ->
  (b = false -> PrePostE P g Q E) ->
  PrePostE P (if b then f else g) Q E.
destruct b; auto.
Qed.

Lemma PrePostE_if_then Regs A Ety (b : bool) (f g : monadS Regs A Ety) P Q E :
  b = true ->
  PrePostE P f Q E ->
  PrePostE P (if b then f else g) Q E.
intros; subst; auto.
Qed.

Lemma PrePostE_if_else Regs A Ety (b : bool) (f g : monadS Regs A Ety) P Q E :
  b = false ->
  PrePostE P g Q E ->
  PrePostE P (if b then f else g) Q E.
intros; subst; auto.
Qed.

Lemma PrePostE_prod_cases (*[PrePostE_compositeI]:*) Regs A B C Ety x (f : A -> B -> monadS Regs C Ety) P Q E :
  PrePostE P (f (fst x) (snd x)) Q E ->
  PrePostE P (match x with (a, b) => f a b end) Q E.
destruct x; auto.
Qed.

Lemma PrePostE_option_cases (*[PrePostE_compositeI]:*) Regs A B Ety x (s : option A -> monadS Regs B Ety) n PS PN Q E :
  (forall a, PrePostE (PS a) (s a) Q E) ->
  PrePostE PN n Q E ->
  PrePostE (match x with Some a => PS a | None => PN end) (match x with Some a => s a | None => n end) Q E.
apply PrePost_option_cases.
Qed.

Lemma PrePostE_sum_cases (*[PrePostE_compositeI]:*) Regs A B C Ety x (l : A -> monadS Regs C Ety) (r : B -> monadS Regs C Ety) Pl Pr Q E :
  (forall a, PrePostE (Pl a) (l a) Q E) ->
  (forall b, PrePostE (Pr b) (r b) Q E) ->
  PrePostE (match x with inl a => Pl a | inr b => Pr b end) (match x with inl a => l a | inr b => r b end) Q E.
intros; destruct x; auto.
Qed.

Lemma PrePostE_let (*[PrePostE_compositeI]:*) Regs A B Ety y (m : A -> monadS Regs B Ety) P Q E :
  PrePostE P (m y) Q E ->
  PrePostE P (let x := y in m x) Q E.
auto.
Qed.

Lemma PrePostE_and_boolS (*[PrePostE_compositeI]:*) Regs Ety (l r : monadS Regs bool Ety) P Q R E :
  PrePostE R r Q E ->
  PrePostE P l (fun r => if r then R else Q false) E ->
  PrePostE P (and_boolS l r) Q E.
intros Hr Hl.
unfold and_boolS.
eapply PrePostE_bindS.
* intros.
  instantiate (1 := fun a => if a then R else Q false).
  destruct a; eauto.
  apply PrePostE_returnS.
* assumption.
Qed.

Lemma PrePostE_or_boolS (*[PrePostE_compositeI]:*) Regs Ety (l r : monadS Regs bool Ety) P Q R E :
  PrePostE R r Q E ->
  PrePostE P l (fun r => if r then Q true else R) E ->
  PrePostE P (or_boolS l r) Q E.
intros Hr Hl.
unfold or_boolS.
eapply PrePostE_bindS.
* intros.
  instantiate (1 := fun a => if a then Q true else R).
  destruct a; eauto.
  apply PrePostE_returnS.
* assumption.
Qed.

Lemma PrePostE_failS (*[PrePostE_atomI, intro]:*) Regs A Ety msg (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (E (Failure msg)) (failS msg) Q E.
unfold PrePostE, PrePost, failS.
intros s Pre r s' [[= <- <-] | []].
assumption.
Qed.

Lemma PrePostE_assert_expS (*[PrePostE_atomI, intro]:*) Regs Ety (c : bool) m P (Q : ex Ety -> predS Regs) :
  PrePostE (if c then P tt else Q (Failure m)) (assert_expS c m) P Q.
unfold assert_expS.
destruct c; auto using PrePostE_returnS, PrePostE_failS.
Qed.

Lemma PrePostE_maybe_failS (*[PrePostE_atomI]:*) Regs A Ety msg v (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (fun s => match v with Some v => Q v s | None => E (Failure msg) s end) (maybe_failS msg v) Q E.
unfold maybe_failS.
destruct v; auto using PrePostE_returnS, PrePostE_failS.
Qed.

Lemma PrePostE_exitS (*[PrePostE_atomI, intro]:*) Regs A Ety msg (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (E (Failure "exit")) (exitS msg) Q E.
unfold exitS.
apply PrePostE_failS.
Qed.

Lemma PrePostE_chooseS (*[intro, PrePostE_atomI]:*) Regs A Ety (xs : list A) (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (fun s => forall x, List.In x xs -> Q x s) (chooseS xs) Q E.
unfold chooseS.
intros s IN r s' IN'.
apply List.in_map_iff in IN'.
destruct IN' as (x & [= <- <-] & IN').
auto.
Qed.

Lemma PrePostE_throwS (*[PrePostE_atomI]:*) Regs A Ety e (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (E (Throw e)) (throwS e) Q E.
unfold throwS.
intros s Pre r s' [[= <- <-] | []].
assumption.
Qed.

Lemma PrePostE_try_catchS (*[PrePostE_compositeI]:*) Regs A E1 E2 m h P (Ph : E1 -> predS Regs) (Q : A -> predS Regs) (E : ex E2 -> predS Regs) :
  (forall s e s', List.In (Ex (Throw e), s') (m s) -> PrePostE (Ph e) (h e) Q E) ->
  PrePostE P m Q (fun ex => match ex with Throw e => Ph e | Failure msg => E (Failure msg) end) ->
  PrePostE P (try_catchS m h) Q E.
intros.
intros s Pre r s' IN.
destruct (try_catchS_cases IN) as [(a' & [= ->] & IN') | [(msg & [= ->] & IN') | (e & s'' & IN1 & IN2)]].
* specialize (H0 _ Pre _ _ IN'). apply H0.
* specialize (H0 _ Pre _ _ IN'). apply H0.
* specialize (H _ _ _ IN1). specialize (H0 _ Pre _ _ IN1). simpl in *.
    specialize (H _ H0 _ _ IN2). apply H.
Qed.

Lemma PrePostE_catch_early_returnS (*[PrePostE_compositeI]:*) Regs A Ety m P (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE P m Q (fun ex => match ex with Throw (inl a) => Q a | Throw (inr e) => E (Throw e) | Failure msg => E (Failure msg) end) ->
  PrePostE P (catch_early_returnS m) Q E.
unfold catch_early_returnS.
intro H.
apply PrePostE_try_catchS with (Ph := fun e => match e with inl a => Q a | inr e => E (Throw e) end).
* intros. destruct e.
  + apply PrePostE_returnS.
  + apply PrePostE_throwS.
* apply H.
Qed.

Lemma PrePostE_early_returnS (*[PrePostE_atomI]:*) Regs A E1 E2 r (Q : A -> predS Regs) (E : ex (E1 + E2) -> predS Regs) :
  PrePostE (E (Throw (inl r))) (early_returnS r) Q E.
unfold early_returnS.
apply PrePostE_throwS.
Qed.

Lemma PrePostE_liftRS (*[PrePostE_compositeI]:*) Regs A E1 E2 m P (Q : A -> predS Regs) (E : ex (E1 + E2) -> predS Regs) :
  PrePostE P m Q (fun ex => match ex with Throw e => E (Throw (inr e)) | Failure msg => E (Failure msg) end) ->
  PrePostE P (liftRS m) Q E.
unfold liftRS.
apply PrePostE_try_catchS.
auto using PrePostE_throwS.
Qed.

Lemma PrePostE_foreachS_Cons Regs A Vars Ety (x : A) xs vars body (Q : Vars -> predS Regs) (E : ex Ety -> predS Regs) :
  (forall s vars' s', List.In (Value vars', s') (body x vars s) -> PrePostE (Q vars') (foreachS xs vars' body) Q E) ->
  PrePostE (Q vars) (body x vars) Q E ->
  PrePostE (Q vars) (foreachS (x :: xs) vars body) Q E.
intros.
simpl.
apply PrePostE_bindS with (R := Q); auto.
Qed.

Lemma PrePostE_foreachS_invariant Regs A Vars Ety (xs : list A) vars body (Q : Vars -> predS Regs) (E : ex Ety -> predS Regs) :
  (forall x vars, List.In x xs -> PrePostE (Q vars) (body x vars) Q E) ->
  PrePostE (Q vars) (foreachS xs vars body) Q E.
unfold PrePostE.
intros H.
apply PrePost_foreachS_invariant with (Q := fun v => match v with Value a => Q a | Ex e => E e end).
auto.
Qed.


Lemma PrePostE_use_pre Regs A Ety m (P : predS Regs) (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  (forall s, P s -> PrePostE P m Q E) ->
  PrePostE P m Q E.
unfold PrePostE, PrePost.
intros H s p r s' IN.
eapply H; eauto.
Qed.

Local Open Scope Z.
Local Opaque _limit_reduces.
Ltac gen_reduces :=
  match goal with |- context[@_limit_reduces ?a ?b ?c] => generalize (@_limit_reduces a b c) end.


Lemma PrePostE_untilST Regs Vars Ety vars measure cond (body : Vars -> monadS Regs Vars Ety) Inv Inv' (Q : Vars -> predS Regs) E :
  (forall vars, PrePostE (Inv' Q vars) (cond vars) (fun c s' => Inv Q vars s' /\ (c = true -> Q vars s')) E) ->
  (forall vars, PrePostE (Inv Q vars) (body vars) (fun vars' s' => Inv' Q vars' s' /\ measure vars' < measure vars) E) ->
  (forall vars s, Inv Q vars s -> measure vars >= 0) ->
  PrePostE (Inv Q vars) (untilST vars measure cond body) Q E.

intros Hcond Hbody Hmeasure.
unfold untilST.
apply PrePostE_use_pre. intros s0 Pre0.
assert (measure vars >= 0) as Hlimit_0 by eauto. clear s0 Pre0.
remember (measure vars) as limit eqn: Heqlimit in Hlimit_0 |- *.
assert (measure vars <= limit) as Hlimit by omega. clear Heqlimit.
generalize (Sail2_prompt.Zwf_guarded limit).
revert vars Hlimit.
apply Wf_Z.natlike_ind with (x := limit).
* intros vars Hmeasure_limit [acc]. simpl.
  eapply PrePostE_bindS; [ | apply Hbody ].
  intros s vars' s' IN.
  eapply PrePostE_bindS with (R := (fun c s' => (Inv Q vars' s' /\ (c = true -> Q vars' s')) /\ measure vars' < measure vars)).
  2: {
    apply PrePostE_weaken_Epost with (E := (fun e s' => E e s' /\ measure vars' < measure vars)). 2: tauto.
    eapply PrePostE_conj_conds.
    apply Hcond.
    apply PrePostE_I; tauto.
  }
  intros.
  destruct a.
  - eapply PrePostE_strengthen_pre; try apply PrePostE_returnS.
    intros ? [[? ?] ?]; auto.
  - apply PrePostE_I;
    intros ? ? ? [[Pre ?] ?] ?; exfalso;
    specialize (Hmeasure _ _ Pre); omega.
* intros limit' Hlimit' IH vars Hmeasure_limit [acc].
  simpl.
  destruct (Z_ge_dec _ _); try omega.
  eapply PrePostE_bindS; [ | apply Hbody].
  intros s vars' s' IN.
  eapply PrePostE_bindS with (R := (fun c s' => (Inv Q vars' s' /\ (c = true -> Q vars' s')) /\ measure vars' < measure vars)).
  2: {
    apply PrePostE_weaken_Epost with (E := (fun e s' => E e s' /\ measure vars' < measure vars)). 2: tauto.
    eapply PrePostE_conj_conds.
    apply Hcond.
    apply PrePostE_I; tauto.
  }
  intros.
  destruct a.
  - eapply PrePostE_strengthen_pre; try apply PrePostE_returnS.
    intros ? [[? ?] ?]; auto.
  - gen_reduces.
    replace (Z.succ limit' - 1) with limit'; [ | omega].
    intro acc'.
    apply PrePostE_use_pre. intros sx [[Pre _] Hreduces].
    apply Hmeasure in Pre.
    eapply PrePostE_strengthen_pre; [apply IH | ].
    + omega.
    + tauto.
* omega.
Qed.


Lemma PrePostE_untilST_pure_cond Regs Vars Ety vars measure cond (body : Vars -> monadS Regs Vars Ety) Inv (Q : Vars -> predS Regs) E :
  (forall vars, PrePostE (Inv Q vars) (body vars) (fun vars' s' => Inv Q vars' s' /\ measure vars' < measure vars /\ (cond vars' = true -> Q vars' s')) E) ->
  (forall vars s, Inv Q vars s -> measure vars >= 0) ->
  (PrePostE (Inv Q vars) (untilST vars measure (fun vars => returnS (cond vars)) body) Q E).
intros Hbody Hmeasure.
apply PrePostE_untilST with (Inv' := fun Q vars s => Inv Q vars s /\ (cond vars = true -> Q vars s)).
* intro.
  apply PrePostE_returnS with (P := fun c s' => Inv Q vars0 s' /\ (c = true -> Q vars0 s')).
* intro.
  eapply PrePost_weaken_post; [ apply Hbody | ].
  simpl. intros [a |e]; eauto. tauto.
* apply Hmeasure.
Qed.

Local Close Scope Z.

(*
lemma PrePostE_liftState_untilM:
  assumes dom: (forall s, Inv Q vars s -> untilM_dom (vars, cond, body))
    and cond: (forall vars, PrePostE (Inv' Q vars) (liftState r (cond vars)) (fun c s' => Inv Q vars s' /\ (c \<longrightarrow> Q vars s')) E)
    and body: (forall vars, PrePostE (Inv Q vars) (liftState r (body vars)) (Inv' Q) E)
  shows "PrePostE (Inv Q vars) (liftState r (untilM vars cond body)) Q E"
proof -
  have domS: "untilS_dom (vars, liftState r \<circ> cond, liftState r \<circ> body, s)" if "Inv Q vars s" for s
    using dom that by (intro untilM_dom_untilS_dom)
  then have "PrePostE (Inv Q vars) (untilS vars (liftState r \<circ> cond) (liftState r \<circ> body)) Q E"
    using cond body by (auto intro: PrePostE_untilS simp: comp_def)
  moreover have "liftState r (untilM vars cond body) s = untilS vars (liftState r \<circ> cond) (liftState r \<circ> body) s"
    if "Inv Q vars s" for s
    unfolding liftState_untilM[OF domS[OF that] dom[OF that]] ..
  ultimately show ?thesis by (auto cong: PrePostE_cong)
qed

lemma PrePostE_liftState_untilM_pure_cond:
  assumes dom: (forall s, Inv Q vars s -> untilM_dom (vars, return \<circ> cond, body)"
    and body: (forall vars, PrePostE (Inv Q vars) (liftState r (body vars)) (fun vars' s' => Inv Q vars' s' /\ (cond vars' \<longrightarrow> Q vars' s')) E"
  shows "PrePostE (Inv Q vars) (liftState r (untilM vars (return \<circ> cond) body)) Q E"
  using assms by (intro PrePostE_liftState_untilM) (auto simp: comp_def liftState_simp)
*)
Lemma PrePostE_choose_boolS_any (*[PrePostE_atomI]:*) Regs Ety unit_val (Q : bool -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (fun s => forall b, Q b s) (choose_boolS unit_val) Q E.
unfold choose_boolS, seqS.
eapply PrePostE_strengthen_pre.
apply PrePostE_chooseS.
simpl. intros. destruct x; auto.
Qed.

Lemma PrePostE_bool_of_bitU_nondetS_any Regs Ety b (Q : bool -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (fun s => forall b, Q b s) (bool_of_bitU_nondetS b) Q E.
unfold bool_of_bitU_nondetS, undefined_boolS.
destruct b.
* intros s Pre r s' [[= <- <-] | []]. auto.
* intros s Pre r s' [[= <- <-] | []]. auto.
* apply PrePostE_choose_boolS_any.
Qed.
(*
Lemma PrePostE_bools_of_bits_nondetS_any:
  PrePostE (fun s => forall bs, Q bs s) (bools_of_bits_nondetS bs) Q E.
  unfolding bools_of_bits_nondetS_def
  by (rule PrePostE_weaken_post[where B = "fun _ s => forall bs, Q bs s"], rule PrePostE_strengthen_pre,
      (rule PrePostE_foreachS_invariant[OF PrePostE_strengthen_pre] PrePostE_bindS PrePostE_returnS
            PrePostE_bool_of_bitU_nondetS_any)+)
     auto
*)
Lemma PrePostE_choose_boolsS_any Regs Ety n (Q : list bool -> predS Regs) (E : ex Ety -> predS Regs) :
  PrePostE (fun s => forall bs, Q bs s) (choose_boolsS n) Q E.
unfold choose_boolsS, genlistS.
apply PrePostE_weaken_post with (B := fun _ s => forall bs, Q bs s).
* apply PrePostE_foreachS_invariant with (Q := fun _ s => forall bs, Q bs s).
  intros. apply PrePostE_bindS with (R := fun _ s => forall bs, Q bs s).
  + intros. apply PrePostE_returnS with (P := fun _ s => forall bs, Q bs s).
  + eapply PrePostE_strengthen_pre.
    apply PrePostE_choose_boolS_any.
    intuition.
* intuition.
Qed.

Lemma nth_error_exists {A} {l : list A} {n} :
  n < Datatypes.length l -> exists x, List.In x l /\ List.nth_error l n = Some x.
revert n. induction l.
* simpl. intros. apply PeanoNat.Nat.nlt_0_r in H. destruct H.
* intros. destruct n.
  + exists a. auto with datatypes.
  + simpl in H. apply Lt.lt_S_n in H.
    destruct (IHl n H) as [x H1].
    intuition eauto with datatypes.
Qed.

Lemma nth_error_modulo {A} {xs : list A} n :
  xs <> nil ->
  exists x, List.In x xs /\ List.nth_error xs (PeanoNat.Nat.modulo n (Datatypes.length xs)) = Some x.
intro notnil.
assert (Datatypes.length xs <> 0) by (rewrite List.length_zero_iff_nil; auto).
assert (PeanoNat.Nat.modulo n (Datatypes.length xs) < Datatypes.length xs) by auto using PeanoNat.Nat.mod_upper_bound.
destruct (nth_error_exists H0) as [x [H1 H2]].
exists x.
auto.
Qed.

Lemma PrePostE_internal_pick Regs A Ety (xs : list A) (Q : A -> predS Regs) (E : ex Ety -> predS Regs) :
  xs <> nil ->
  PrePostE (fun s => forall x, List.In x xs -> Q x s) (internal_pickS xs) Q E.
unfold internal_pickS.
intro notnil.
eapply PrePostE_bindS with (R := fun _ s => forall x, List.In x xs -> Q x s).
* intros.
  destruct (nth_error_modulo (Sail2_values.nat_of_bools a) notnil) as (x & IN & nth).
  rewrite nth.
  eapply PrePostE_strengthen_pre.
  apply PrePostE_returnS.
  intuition.
* eapply PrePostE_strengthen_pre.
  apply PrePostE_choose_boolsS_any.
  intuition.
Qed.
