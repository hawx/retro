describe('when thinking', () => {
  it('checks the response first', () => {
    cy.visit('http://localhost:8080/')
      .then((resp) => {
        console.log(resp.status);
        console.log(resp.headers);
        console.log(resp.body);
      });
  });

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
    cy.contains('.column', 'Start').within((column) => {
      cy.get('textarea').type('halp');
      cy.get('a').click();
      cy.get('.card').its('length').should('eq', 2);
      cy.get('.card').contains('halp');
    });
  });

  it('edits the card', () => {
    cy.contains('.card', 'halp').within((card) => {
      cy.get('.card-content').dblclick();
      cy.get('textarea').type('pls{enter}');
      cy.root().contains('halppls');
    });
  });

  it('moves the card', () => {
    cy.contains('.card', 'halp').within((card) => {
      cy.root().trigger('mouseover');
    });

    cy.contains('.column', 'More').within((column) => {
      cy.root().trigger('dragover');
      cy.root().trigger('drop');
    });
  });

  it('deletes the card', () => {
    cy.contains('.column', 'More').within((column) => {
      cy.get('.card .delete').click();
      cy.get('.card').its('length').should('eq', 1);
    });
  });
});
