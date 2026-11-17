**You:**

Matt Kaufman asked about the possibility of how this ACL2(r) proof could be adapted to regular ACL2 thru some trust tag and rational bounds.  Can you figure out how to do that 
https://www.cs.utexas.edu/~moore/acl2/workshop-2026/slides/basel-talk.pdf

* * *

**ChatGPT:**

**Yes. There is a clean way to do this: retain the analytic proof in ACL2(r), export a rational-only finite-bound theorem through a narrowly scoped trusted clause processor, and finish the convergence argument in ordinary ACL2.** The important point is to export the bounds *before* Ruben takes standard parts.

I found the actual books on the [`acl2r-context` branch](https://github.com/acl2/acl2/tree/acl2r-context/books/nonstd/basel), and checked the relevant definitions and lemmas. What follows is a concrete adaptation, **not yet an ACL2-certified port**.

**1. The existing proof already has the right interface**

Write
\[
O_m=\sum_{j=1}^{m}\frac1{(2j-1)^2}.
\]

Before using nonstandard limits, Ruben establishes, for positive integers \(n\),
\[
\boxed{
\pi^2\left(\frac18-\frac1{2^{n+3}}\right)
\le O_{2^{n-1}}
\le \frac{\pi^2}{8}.
}
\]
This is the bound on PDF page 56. Everything except \(\pi\) is already finite rational arithmetic. genui{"citation":{"ref":"turn833502630view0"}}

In [`basel-series.lisp`](https://github.com/acl2/acl2/blob/acl2r-context/books/nonstd/basel/basel-series.lisp), the relevant lemmas are:

| Existing lemma | What it establishes |
|---|---|
| `big-lower-bound-lemma-specialized-3` | \(O_{2^{n-1}}\le\pi^2/8\) |
| `big-upper-bound-lemma-specialized-6` | The other side of the boxed inequality |

Both lemmas—and `basel-odds` itself—are currently **local**. So this requires a small refactoring to expose the finite result; merely including the current book will not expose them.

**2. Replace \(\pi\) with rational enclosing intervals**

Define ordinary ACL2 functions \(L(p)\) and \(U(p)\) that compute rational bounds on \(\pi\). Prove their connection to \(\pi\) in ACL2(r):
\[
0\le L(p)\le\pi\le U(p).
\]

Then derive and export this theorem:
\[
\boxed{
L(p)^2\left(\frac18-\frac1{2^{n+3}}\right)
\le O_{2^{n-1}}
\le \frac{U(p)^2}{8}
}
\qquad(n,p\ge1).
\]

**That entire statement belongs to ordinary ACL2.** It contains no `acl2-pi`, real-valued trigonometry, `standard-part`, or `i-large`.

There are two sensible milestones:

- **Fixed precision:** reuse the existing [`trig.lisp`](https://github.com/acl2/acl2/blob/master/books/nonstd/nsa/trig.lisp) definitions `m-pi`, `m-pi+eps`, and theorem `pi-tight-bound`. They enclose \(\pi\) between two rationals separated by \(10^{-20}\).
- **Arbitrary precision:** introduce rational interval functions whose width provably tends to zero. This is needed to express the full identity, rather than a fixed numerical enclosure.

For an explicit arbitrary-precision construction, let
\[
A_m(x)=\sum_{j=0}^{m-1}\frac{(-1)^jx^{2j+1}}{2j+1}
\]
and use Machin’s identity to justify
\[
\begin{aligned}
L(p)&=16A_{2p}(1/5)-4A_{2p+1}(1/239),\\
U(p)&=16A_{2p+1}(1/5)-4A_{2p}(1/239).
\end{aligned}
\]
These are executable rational functions. Their exact width is
\[
U(p)-L(p)=
\frac{16}{(4p+1)5^{4p+1}}
+\frac4{(4p+1)239^{4p+1}}.
\]
The connection to \(\pi\) would be an additional ACL2(r) proof obligation; the rational width calculation can be proved in ordinary ACL2.

**3. The rest can use finite algebra instead of nonstandard analysis**

Here is a concrete replacement for the end of the proof.

Define
\[
S_N=\sum_{j=1}^{N}\frac1{j^2}.
\]
For \(N=2^n\), splitting odd and even terms gives
\[
S_N=O_{N/2}+\frac14S_{N/2}.
\]

Ordinary ACL2 can establish the tail bound
\[
0\le S_N-S_{N/2}\le\frac1N
\]
by telescoping, using
\[
\frac1{j^2}\le\frac1{j-1}-\frac1j.
\]
**No integration is needed.**

Setting \(T=S_N-S_{N/2}\), the split identity becomes
\[
S_N=\frac43O_{N/2}-\frac13T.
\]
Substituting the exported rational bounds yields my proposed final finite theorem:
\[
\boxed{
\frac{L(p)^2}{6}
-\frac{L(p)^2+2}{6\cdot2^n}
\le S_{2^n}
\le\frac{U(p)^2}{6}.
}
\]

Its enclosure width is explicitly
\[
\frac{U(p)^2-L(p)^2}{6}
+\frac{L(p)^2+2}{6\cdot2^n}.
\]
Both terms can be made arbitrarily small.

This gives ordinary ACL2 a precise formulation of the Basel identity: **the rational partial sums and the rational approximations to \(\pi^2/6\) approach each other with a proved error bound.** The same telescoping tail argument extends the result beyond the dyadic subsequence.

**4. What exactly the trust tag would cover**

I would use `define-trusted-clause-processor` to admit **only the specific rational enclosure theorem proved in ACL2(r)**. ACL2 explicitly supports registering such processors with a `:ttag`; its documentation also requires recording the supporting function definitions. genui{"citation":{"ref":"turn412579295view0"}}

The implementation should:

1. Put the rational sums and approximation functions in a shared book certifiable in both systems.
2. Prove the rational enclosure theorem in ACL2(r), using Ruben’s two finite lemmas.
3. Have the trusted processor recognize that precise theorem, with its hypotheses and matching definitions.
4. Prove the splitting, telescoping, error propagation, and arbitrary-precision result normally in ACL2.

The trust obligation is the **specific transfer between the two systems**, including correspondence of the shared definitions. A trust tag records that obligation; it does not itself establish soundness.

In particular, we must not introduce a single ordinary ACL2 number called `pi` and constrain it with arbitrarily tight bounds. Use a **precision-indexed rational representation** instead.

**My recommendation to Matt:** start by exporting the odd-sum bound using the existing 20-decimal \(\pi\) enclosure. That demonstrates the bridge with little additional analysis. Then generalize to variable precision to obtain the full identity in rational-sequence form.

I checked the derived finite inequalities with exact rational arithmetic for \(N=2,4,\ldots,1024\). Those checks support the algebra and indexing; certification of the refactored books and bridge remains to be done.

* * *

**You:**

Can you write the necessary ACL2?

* * *

**You:**

Please continue

* * *

**ChatGPT:**

Implemented and **certified both sides**.

[](https://chatgpt.com/library?file_id=libfile_f0fd5b79290881918c4055d9d59350eb&account_id=personal)

Includes:

- ACL2(r) proof of the exported rational enclosure.
- A trust-tag bridge accepting exactly that theorem.
- Ordinary ACL2 proofs of the tail bounds, Cauchy estimate, and full-sum enclosure.
- A certified \(2^{80}\)-term example without evaluating the sum.
- Reproduction instructions and successful certification logs.

This version uses the existing **20-decimal π bounds**. The rational endgame supports arbitrary endpoints, but the arbitrary-precision π extension is not implemented.

basel-acl2-rational-bounds.zip