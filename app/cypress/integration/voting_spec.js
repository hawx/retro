describe('when voting', () => {
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

  it('adds votes to a card', () => {
    cy.contains('.card', 'cool').within((column) => {
      cy.contains('+').click();
      cy.contains('+').click();
      cy.contains('+').click();

      cy.contains('3');
    });
  });

  it('removes votes from a card', () => {
    cy.contains('.card', 'cool').within((column) => {
      cy.contains('-').click();
      cy.contains('-').click();

      cy.contains('1');
    });
  });

  it('does not remove votes from a card below 0', () => {
    cy.contains('.card', 'cool').within((column) => {
      cy.contains('-').click();
      cy.contains('-').click();

      cy.contains('0');
    });
  });
});
