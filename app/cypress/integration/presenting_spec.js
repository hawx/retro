describe('when presenting', () => {
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

  it('has no revealed cards', () => {
    cy.get('.card.not-revealed.can-reveal').its('length').should('eq', 3);
  });

  it('reveals a card', () => {
    cy.contains('.column', 'Keep').within((column) => {
      cy.get('.card').click();

      cy.get('.card').should('have.class', 'last-revealed');
    });
  });
});
