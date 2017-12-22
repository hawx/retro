describe('retro', () => {
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

  it('adds a new card', () => {
    cy.get('.column:first-child').within((column) => {
      cy.get('textarea').type('halp');
      cy.get('a').click();
      cy.get('.card').its('length').should('eq', 2);
      cy.get('.card').contains('halp');
    });
  });

  it('edits the card', () => {
    cy.get('.column:first-child .card:not(.add-card)').within((column) => {
      cy.get('.card-content').dblclick();
      cy.get('textarea').type('pls{enter}');
      cy.root().contains('halppls');
    });
  });

  it('deletes the card', () => {
    cy.get('.column:first-child').within((column) => {
      cy.get('.card .delete').click();
      cy.get('.card').its('length').should('eq', 1);
    });
  });
});
