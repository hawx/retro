describe('retro', function() {
  it('visits the app', function() {
    cy.visit('http://localhost:8080/reset');

    cy.contains('Sign-in with Test').click();

    cy.contains('test@example.com');

    cy.get('input').type('First Retro');
    cy.get('#create').click();

    cy.get('#open').click();

    cy.get('.column:first-child').within((column) => {
      cy.get('textarea').type('halp');
      cy.get('a').click();
      cy.get('.card').its('length').should('eq', 2);
      cy.get('.card').contains('halp');

      cy.get('.card .delete').click();
      cy.get('.card').its('length').should('eq', 1);
    });
  });
});
