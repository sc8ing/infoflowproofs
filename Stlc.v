Set Warnings "-notation-overridden,-parsing".
From Coq Require Import Strings.String.
From STLCIF Require Import Maps.
From STLCIF Require Import Smallstep.
Require Import Coq.Strings.String.
Require Import Ascii.
Require Import Bool.

Module STLC.
  Inductive data_type : Type :=
    | Bool  : data_type
    | Arrow : data_type -> data_type -> data_type.

  Definition data_type_eq_dec :
    forall (x y : data_type), { x = y } + { x <> y }.
  Proof. decide equality. Defined.

  Inductive sec_class : Type :=
    | High : sec_class
    | Low : sec_class.

  Definition sec_class_eq_dec :
    forall (x y : sec_class), { x = y } + { x <> y }.
  Proof. decide equality. Defined.

  Inductive exp : Type :=
    | var : string -> exp
    | app : exp -> exp -> exp
    | abs : string -> data_type -> exp -> exp
    | tru : exp
    | fls : exp
    | test : exp -> exp -> exp -> exp
    | marked : sec_class -> exp -> exp
    | hole.

  Open Scope string_scope.
  Definition x := "x".
  Definition y := "y".
  Definition z := "z".
  Hint Unfold x.
  Hint Unfold y.
  Hint Unfold z.

  Inductive value : exp -> Prop :=
    | v_abs :
        forall x T t,
        value (abs x T t)
    | v_tru :
        value tru
    | v_fls :
        value fls
    | v_markedval :
        forall class val,
        value val -> value (marked class val).

  Hint Constructors value.


  Reserved Notation "'[' v '//' x ']' e 'is' r" (at level 40).
  Inductive substi (x : string) (s : exp) : exp -> exp -> Prop :=
    | s_var_eq :
        substi x s (var x) s
    | s_var_neq :
        forall y,
        y <> x ->
        substi x s (var y) (var y)
    | s_abs_eq :
        forall t1 T, substi x s (abs x T t1) (abs x T t1)
    | s_abs_neq :
        forall t1 t1' T,
        x <> y ->
        substi x s t1 t1' ->
        substi x s (abs y T t1) (abs y T t1')
    | s_app :
        forall t1 t1' t2 t2',
        substi x s t1 t1' ->
        substi x s t2 t2' ->
        substi x s (app t1 t2) (app t1' t2')
    | s_tru :
        substi x s tru tru
    | s_fls :
        substi x s fls fls
    | s_test :
        forall t1 t1' t2 t2' t3 t3',
        substi x s t1 t1' ->
        substi x s t2 t2' ->
        substi x s t3 t3' ->
        substi x s (test t1 t2 t3) (test t1' t2' t3')
    | s_marked :
        forall class e e',
        substi x s e e' ->
        substi x s (marked class e) (marked class e')
    | s_hole :
        substi x s hole hole
      where "'[' v '//' x ']' e 'is' r" := (substi x v e r)
  .
  Hint Constructors substi.

  Reserved Notation "t1 '-->' t2" (at level 40).
  Inductive step : exp -> exp -> Prop :=
    | ST_AppAbs :
        forall x T t12 v2 subres,
        [v2//x] t12 is subres ->
        (app (abs x T t12) v2) --> subres

    | ST_App1 :
        forall t1 t1' t2,
        t1 --> t1' ->
        app t1 t2 --> app t1' t2

    | ST_TestTru :
        forall t1 t2,
        (test tru t1 t2) --> t1

    | ST_TestFls :
        forall t1 t2,
        (test fls t1 t2) --> t2

    | ST_Test :
        forall t1 t1' t2 t3,
        t1 --> t1' ->
        (test t1 t2 t3) --> (test t1' t2 t3)

    | ST_LiftApp :
        forall class func e,
        (app (marked class func) e) --> (marked class (app func e))

    | ST_LiftTestCond :
        forall class cond b1 b2,
        (test (marked class cond) b1 b2) --> (marked class (test cond b1 b2))

    | ST_MarkReduce :
        forall class body body',
        body --> body' ->
        (marked class body) --> (marked class body')

    where "t1 '-->' t2" := (step t1 t2).

  Hint Constructors step.

  Notation multistep := (multi step).
  Notation "t1 '-->*' t2" := (multistep t1 t2) (at level 40).


  Definition context := partial_map data_type.

  Reserved Notation "Gamma '|-' t '\in' T" (at level 40).

  Inductive has_dtype : context -> exp -> data_type -> Prop :=
    | T_Var : forall Gamma x T,
        Gamma x = Some T ->
        Gamma |- var x \in T

    | T_Abs : forall Gamma x T11 T12 t12,
        (x |-> T11 ; Gamma) |- t12 \in T12 ->
        Gamma |- abs x T11 t12 \in Arrow T11 T12

    | T_App : forall T11 T12 Gamma t1 t2,
        Gamma |- t1 \in Arrow T11 T12 ->
        Gamma |- t2 \in T11 ->
        Gamma |- app t1 t2 \in T12

    | T_Tru : forall Gamma,
        Gamma |- tru \in Bool
    | T_Fls : forall Gamma,
        Gamma |- fls \in Bool

    | T_Test : forall t1 t2 t3 T Gamma,
        Gamma |- t1 \in Bool ->
        Gamma |- t2 \in T ->
        Gamma |- t3 \in T ->
        Gamma |- test t1 t2 t3 \in T

    | T_Marked : forall Gamma class e T,
        Gamma |- e \in T ->
        Gamma |- marked class e \in T
    where "Gamma '|-' t '\in' T" := (has_dtype Gamma t T).

  Hint Constructors has_dtype.

  Reserved Notation "a << b" (at level 40).

  Inductive holier : exp -> exp -> Prop :=
    | H_refl :
        forall e,
        e << e

    | H_hole :
        forall e,
        hole << e

    | H_app :
        forall func arg func' arg',
        func << func' ->
        arg << arg' ->
        (app func arg) << (app func' arg')

    | H_abs :
        forall x T body body',
        body << body' ->
        (abs x T body) << (abs x T body')

    | H_test :
        forall cond b1 b2 cond' b1' b2',
        cond << cond' ->
        b1 << b1' ->
        b2 << b2' ->
        (test cond b1 b2) << (test cond' b1' b2')

    | H_marked :
        forall class body body',
        body << body' ->
        (marked class body) << (marked class body')

    where "a << b" := (holier a b).

  Hint Constructors holier.

  Inductive noholes : exp -> Prop :=
    | NH_var : forall s,
        noholes (var s)

    | NH_app : forall func arg,
        noholes func -> noholes arg ->
        noholes (app func arg)

    | NH_abs : forall x T func,
        noholes func ->
        noholes (abs x T func)

    | NH_tru : noholes tru
    | NH_fls : noholes fls

    | NH_test : forall cond b1 b2,
        noholes cond -> noholes b1 -> noholes b2 ->
        noholes (test cond b1 b2)

    | NH_marked : forall class body,
        noholes body ->
        noholes (marked class body).

  Lemma holyval_meansval : forall v1 v2,
    value v1 ->
    v1 << v2 ->
    value v2.
  Proof.
    intros. generalize dependent v2.
    induction H; intros; inversion H0; try constructor.
    - assumption.
    - subst. apply IHvalue. assumption.
  Qed.

  Lemma holier_abs_inv : forall x T body e',
    (abs x T body) << e' ->
    exists body', body << body' /\ e' = (abs x T body').
  Proof.
    intros. inversion H; subst.
    - induction body; eexists; eauto.
    - exists body'. auto.
  Qed.


  Lemma subst_noholes : forall x body arg result,
    [ arg // x ] body is result ->
    noholes result ->
    noholes body.
  Proof.
    intros. induction H; try constructor; auto.
    - inversion H0; subst. auto.
    - inversion H0; subst.
      apply IHsubsti in H3. auto.
    - inversion H0; subst.
      apply IHsubsti1 in H4. auto.
    - inversion H0; subst.
      apply IHsubsti2 in H5. auto.
    - inversion H0; subst.
      apply IHsubsti1 in H6. auto.
    - inversion H0; subst.
      apply IHsubsti2 in H7. auto.
    - inversion H0; subst.
      apply IHsubsti3 in H8. auto.
    - inversion H0; subst.
      apply IHsubsti in H2. auto.
  Qed.


  Lemma noholes_app_arg_orunused : forall x body arg f,
  noholes f ->
  [arg // x] body is f ->
  noholes arg \/ forall xsub, [xsub // x] body is f.
  Proof.
    intros. induction H0.
    - left. assumption.
    - right. intros. econstructor. auto.
    - right. intros. constructor.
    - inversion H; subst.
      specialize H3 as H3'. apply IHsubsti in H3.
      destruct H3 as [argnoholes | argunused].
      * left. assumption.
      * right. intros. constructor.
        eauto. eauto.
    - inversion H; subst.
      specialize H2 as H2'.
      specialize H3 as H3'.
      apply IHsubsti1 in H2.
      apply IHsubsti2 in H3.
      destruct H2 as [nh1 | unused1].
      + left. assumption.
      + destruct H3 as [nh2 | unused2].
        * left. assumption.
        * right. intros. constructor.
          auto. auto.
    - right. constructor.
    - right. constructor.
    - inversion H; subst.
      specialize H3 as H3'.
      specialize H4 as H4'.
      specialize H5 as H5'.
      apply IHsubsti1 in H3.
      apply IHsubsti2 in H4.
      apply IHsubsti3 in H5.
      destruct H3 as [nht1 | t1unused]. auto.
      destruct H4 as [nht2 | t2unused]. auto.
      destruct H5 as [nht3 | t3unused]. auto.
      auto.
    - inversion H; subst.
      specialize H2 as H2'.
      apply IHsubsti in H2.
      destruct H2 as [nh | unused]; auto.
    - inversion H.
  Qed.


  Lemma noholes_holier_means_eq : forall e e',
    noholes e ->
    e << e' ->
    e = e'.
  Proof.
    intros. generalize dependent e'. induction H; intros; subst.
    - inversion H0. auto.
    - inversion H1; subst; auto.
      apply IHnoholes1 in H4.
      apply IHnoholes2 in H6.
      subst. auto.
    - inversion H0; subst; auto.
      apply IHnoholes in H5; subst; auto.
    - inversion H0; subst; auto.
    - inversion H0; subst; auto.
    - inversion H2; subst; auto.
      apply IHnoholes1 in H6.
      apply IHnoholes2 in H8.
      apply IHnoholes3 in H9.
      subst. auto.
    - inversion H0; subst; auto.
      apply IHnoholes in H4; subst; auto.
  Qed.

  Lemma bodystepsappsteps : forall body arg body',
    body -->* body' ->
    (app body arg) -->* (app body' arg).
  Proof.
    intros. induction H; subst.
    - constructor.
    - apply multi_step with (app y0 arg); auto.
  Qed.

  Lemma condstepsteststeps : forall cond cond' b1 b2,
    cond -->* cond' ->
    (test cond b1 b2) -->* (test cond' b1 b2).
  Proof.
    intros. induction H; subst.
    - constructor.
    - apply multi_step with (test y0 b1 b2); auto.
  Qed.

  Lemma markedbodstepstermsteps : forall class body body',
    body -->* body' ->
    (marked class body) -->* (marked class body').
  Proof.
    intros. induction H; subst.
    - constructor.
    - apply multi_step with (marked class y0); auto.
  Qed.
  
  Lemma monotonicity_single_step : forall e e' f,
    noholes f ->
    e << e' ->
    e --> f ->
    e' -->* f.
  Proof.
    intros. generalize dependent f. induction H0; intros.
    - apply multi_R. assumption.
    - inversion H1; subst.
    - inversion H1; subst.
      + apply holier_abs_inv in H0_.
        destruct H0_ as [body' [bodyprop funcprop]].
        subst. specialize H0_0 as H'.
        eapply multi_R.
        specialize H4 as H4'.
        apply noholes_app_arg_orunused in H4; eauto.
        destruct H4 as [nh | unused].
        * apply noholes_holier_means_eq in H'.
          subst.
          apply subst_noholes in H4'; eauto.
          apply noholes_holier_means_eq in bodyprop; eauto.
          subst. eauto. assumption.
        * apply subst_noholes in H4'; eauto.
          apply noholes_holier_means_eq in bodyprop; eauto.
          subst.
          constructor; eauto.
      + inversion H; subst.
        apply noholes_holier_means_eq in H0_0; eauto.
        subst.
        eapply bodystepsappsteps.
        apply IHholier1; eauto.
      + apply noholes_holier_means_eq in H0_; subst; eauto.
        inversion H; subst. inversion H2; subst.
        apply noholes_holier_means_eq in H0_0; subst; eauto.
        apply multi_R. eauto.
        inversion H; subst. inversion H2; subst.
        constructor. auto.
    - inversion H1.
    - inversion H1; subst.
      + apply noholes_holier_means_eq in H0_; subst; eauto.
        apply noholes_holier_means_eq in H0_0; subst; eauto.
        apply multi_R.
        constructor.
        constructor.
      + apply noholes_holier_means_eq in H0_; subst; eauto.
        apply noholes_holier_means_eq in H0_1; subst; eauto.
        apply multi_R.
        constructor.
        constructor.
      + inversion H; subst.
        apply noholes_holier_means_eq in H0_0; subst; auto.
        apply noholes_holier_means_eq in H0_1; subst; auto.
        apply IHholier1 in H5; auto.
        apply condstepsteststeps. auto.
      + inversion H; subst.
        apply noholes_holier_means_eq in H0_; subst; auto.
        apply noholes_holier_means_eq in H0_0; subst; auto.
        apply noholes_holier_means_eq in H0_1; subst; auto.
        apply multi_R. apply ST_LiftTestCond.
        inversion H2; subst; auto.
        inversion H2; subst; auto.
        constructor. inversion H2; subst; auto.
    - inversion H1; subst.
      inversion H; subst.
      apply IHholier in H3; auto.
      apply markedbodstepstermsteps. assumption.
  Qed.


  Lemma monotonicity : forall e e' f,
    noholes f ->
    e << e' ->
    e -->* f ->
    e' -->* f.
  Proof.
    intros. generalize dependent e'.
    induction H1.
    - intros. apply noholes_holier_means_eq in H0; subst; auto.
      apply multi_refl.
    - intros. eapply monotonicity_single_step in H0.
      + apply IHmulti; auto.
  Admitted.


  Lemma multi_ind_rev :
    forall (X : Type) (R : relation X) (P : X -> X -> Prop),
    (forall x : X, P x x) ->
    (forall x y z : X, R y z -> multi R x y -> P x y -> P x z) ->
    forall y y0 : X, multi R y y0 -> P y y0.
  Proof.
  Admitted.

  Lemma monotonicity_rev_ind : forall e e' f,
    noholes f ->
    e << e' ->
    e -->* f ->
    e' -->* f.
  Proof.
    intros. generalize dependent e'.
    induction H1.
    - intros. apply noholes_holier_means_eq in H0; subst; auto.
      apply multi_refl.
    - intros. eapply monotonicity_single_step in H0.
      + apply IHmulti; auto.
  Admitted.
  
  Lemma monotonicity_single_step' : forall e e' f,
    e << e' ->
    e --> f ->
    exists f', e' -->* f' /\ f << f'.
  Proof.
  Admitted.

  Lemma monotonicity' : forall e e' f,
    e << e' ->
    e -->* f ->
    exists f', e' -->* f' /\ f << f'.
  Proof.
  Admitted.

  Fixpoint prune_single (l : sec_class) (e : exp) : exp :=
    match e with
    | app func arg =>
        let func' := prune_single l func in
        let arg' := prune_single l arg in
        app func' arg'

    | abs x T body => abs x T (prune_single l body)

    | test cond b1 b2 =>
        let cond' := prune_single l cond in
        let b1' := prune_single l b1 in
        let b2' := prune_single l b2 in
        test cond' b1' b2'

    | (marked lab body) as e =>
        if sec_class_eq_dec lab l then hole else (marked lab (prune_single l body))

    | other => other
    end.

  Definition prune (allowed : list sec_class) (e : exp) : exp :=
    List.fold_left (fun e' lab => prune_single lab e') allowed e.

  Notation "\\ e //_ labs" := (prune labs e) (at level 40).

  Lemma subprunenoorder : forall v x body result lab,
    [v // x] body is result ->
    \\result//_(lab::nil) = result ->
    [\\v//_(lab::nil) // x] \\body//_(lab::nil) is result.
  Proof.
    intros. induction H; subst; try (simpl in *; auto).
    - rewrite H0. constructor.
    - inversion H0. repeat (rewrite H1). constructor.
    - constructor; try assumption. apply IHsubsti. 
      inversion H0. congruence.
    - constructor.
      + apply IHsubsti1. inversion H0; congruence.
      + apply IHsubsti2. inversion H0; congruence.
    - constructor.
      + apply IHsubsti1. inversion H0; congruence.
      + apply IHsubsti2. inversion H0; congruence.
      + apply IHsubsti3. inversion H0; congruence.
    - destruct (sec_class_eq_dec class lab) as [eq | neq].
      + discriminate H0.
      + constructor. apply IHsubsti.
        inversion H0; congruence.
     Qed.


 Lemma prunesubst_commute : forall lab v x body result,
    [v // x] body is result ->
    [(prune_single lab v) // x] (prune_single lab body) is (prune_single lab result).
  Proof.
    intros. induction H; subst; try (simpl; auto).
    destruct (sec_class_eq_dec class lab); auto.
  Qed.

  Lemma stabilitysinglestep_tooweak : forall e f lab,
    noholes f ->
    e --> f ->
    (\\ f //_ (lab::nil)) = f ->
    \\ e //_ (lab::nil) -->* f.
  Proof.
    intros. induction H0; subst.
    - simpl. apply multi_R. constructor.
      apply subprunenoorder. auto. auto.
    - simpl in *. inversion H1. rewrite H4. rewrite H4.
      apply bodystepsappsteps.
      rewrite H3. apply IHstep.
      + inversion H; subst; auto.
      + auto.
    - simpl in *. apply multi_R. rewrite H1; auto.
    - simpl in *. apply multi_R. rewrite H1; auto.
    - simpl in *. inversion H1; subst.
      repeat (rewrite H4).
      repeat (rewrite H5).
      repeat (rewrite H3).
      apply condstepsteststeps.
      apply IHstep; auto. inversion H; subst; auto.
    - simpl in *. destruct (sec_class_eq_dec class lab).
      + apply multi_R. inversion H1.
      + apply multi_R. inversion H1.
        repeat (rewrite H2).
        repeat (rewrite H3).
        constructor.
    - simpl in *. destruct (sec_class_eq_dec class lab).
      + inversion H1.
      + inversion H1.
        repeat (rewrite H2).
        repeat (rewrite H3).
        repeat (rewrite H4).
        apply multi_R. auto.
    - simpl in *. destruct (sec_class_eq_dec class lab).
      + inversion H1.
      + apply markedbodstepstermsteps. 
        apply IHstep. inversion H; subst; auto.
        inversion H1; subst. congruence.
  Qed.

  Lemma stabilitysinglestep : forall e f lab,
    e --> f ->
    \\ e //_ (lab :: nil) -->* (\\ f //_ (lab :: nil))
    \/
    \\ f //_ (lab :: nil) << \\ e //_ (lab :: nil).
  Proof.
    intros. induction H.
    - left. simpl. apply multi_R. constructor.
      apply prunesubst_commute; auto.
    - destruct IHstep as [L | R].
      + left. simpl in *. apply bodystepsappsteps. auto.
      + right. simpl in *. constructor; auto.
    - left. simpl. apply multi_R. constructor.
    - left. simpl. apply multi_R. constructor.
    - destruct IHstep as [L | R].
      + left. simpl in *. apply condstepsteststeps. auto.
      + right. simpl in *. constructor; auto.
    - simpl. destruct (sec_class_eq_dec class lab) as [eq | neq].
      + right. constructor.
      + left. apply multi_R. constructor.
    - simpl. destruct (sec_class_eq_dec class lab) as [eq | neq].
      + right. constructor.
      + left. apply multi_R. constructor.
    - simpl.
      destruct (sec_class_eq_dec class lab) as [eq | neq].
      left. constructor.
      destruct IHstep.
      + simpl in H0. left.
        apply markedbodstepstermsteps. auto.
      + right. simpl in *.
        constructor; auto.
  Qed.


  Lemma stability : forall e f lab,
    noholes f ->
    e -->* f ->
    (\\ f //_(lab :: nil)) = f ->
    \\ e //_(lab :: nil) -->* f.
  Proof.
    intros. induction H0.
    - rewrite H1; constructor.
    - apply stabilitysinglestep with
      (e := x0) (f := y0) (lab := lab) in H0.
      destruct H0 as [L | R].
      + eapply multi_trans.
        * apply L.
        * apply IHmulti; auto.
      + eapply monotonicity; eauto.
  Qed.

  (*
    Lemma non_interference' : forall Gamma e T v lab,
        Gamma |- e \in T ->
        secclass e is lab ->
        e -->* v ->
        \\e//_(lab::nil) -->* v.
    Proof.
    intros.
    Admitted.
  *)

  (*
    Lemma non_interference : forall e f lab v T Gamma,
        Gamma |- e \in T ->
        Gamma |- f \in T ->
        value v ->
        \\e//_(lab::nil) = \\f//_(lab::nil) ->
        (e -->* v) = (f -->* v).
    Proof.
    intros.
    Admitted.
  *)

End STLC.

