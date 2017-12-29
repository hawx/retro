describe('when discussing', () => {
  it('can sign-in', () => {
    cy.visit('http://localhost:8080/reset');

    cy.contains('Sign-in with Test').click();

    cy.contains('test@example.com');
  });

  it('creates a new retro', () => {
    cy.get('input').type('First Retro');
    cy.get('#create').click();

    cy.get('#open').click();
  });

  it('adds some cards', () => {
    cy.contains('.column', 'Start').within((column) => {
      cy.get('textarea').type('halp');
      cy.get('a').click();

      cy.get('textarea').type('ok');
      cy.get('a').click();

      cy.get('.card').its('length').should('eq', 3);
    });

    cy.contains('.column', 'Keep').within((column) => {
      cy.get('textarea').type('cool');
      cy.get('a').click();
    });
  });

  it('moves to presenting', () => {
    cy.contains('Presenting').click();
  });

  it('reveals the cards', () => {
    cy.get('.card').click({multiple: true});
  });

  it('moves to voting', () => {
    cy.contains('Voting').click();
  });

  it('votes on the cards', () => {
    cy.contains('.card', 'cool').within((column) => {
      cy.contains('+').click();
      cy.contains('+').click();
      cy.contains('+').click();

      cy.contains('3');
    });

    cy.contains('.card', 'halp').within((card) => {
      cy.contains('+').click();
    });
  });

  it('moves to discussing', () => {
    cy.contains('Discussing').click();
  });

  it('orders the cards by votes', () => {
    cy.contains('.column', '3').within((column) => {
      cy.contains('cool');
    });

    cy.contains('.column', '1').within((column) => {
      cy.contains('halp');
    });

    cy.contains('.column', '0').within((column) => {
      cy.contains('ok');
    });
  });
});
