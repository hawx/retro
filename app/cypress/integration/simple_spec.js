describe('retro', function() {
  it('visits the app', function() {
    cy.visit('http://localhost:8080/reset');

    cy.contains('Sign-in with Test').click();

    cy.contains('test@example.com');

    cy.get('input').type('First Retro');
    cy.get('#create').click();

    cy.get('#open').click();
  });
});
