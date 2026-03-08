import pytest
from unittest.mock import Mock
from src.adapters.repositories import InMemoryPessoaRepository
from src.domain.models.pessoa import Pessoa
from src.domain.ports.pessoa_repository_port import PessoaRepositoryPort
from src.adapters.repositories import InMemoryPessoaRepository

@pytest.fixture()
def pessoa_repository():
    return InMemoryPessoaRepository()

class TestPessoaRepositoryPort():
    @classmethod
    def setup_class(cls):
        cls.aline_nome = 'Aline da Silva'
        cls.aline_cpf = '139.649.293-36'
        cls.pessoa_aline = Pessoa(cls.aline_nome, cls.aline_cpf)
        cls.pessoa_joao = Pessoa("Joao", "762.263.731-99")

    def test_deve_retornar_sucesso_ao_salvar_pessoa(self, pessoa_repository):
        mock_repository = Mock(spec=InMemoryPessoaRepository)
        pessoa_repository_port = PessoaRepositoryPort(mock_repository)
    
        #Definindo o comportamento esperado do mock
        mock_repository.salvar.return_value =  self.pessoa_aline
    
        pessoa_cadastrada = pessoa_repository_port.salvar(self.aline_nome, self.aline_cpf)
    
        mock_repository.salvar.assert_called_once()
       
        assert pessoa_cadastrada is not None
        assert pessoa_cadastrada.cpf == self.aline_cpf
        assert pessoa_cadastrada.nome == self.aline_nome
    
    def test_deve_retornar_sucesso_quando_obter_lista_pessoas_cadastradas(self):
        mock_repository = Mock(spec=InMemoryPessoaRepository)
        pessoa_repository_port = PessoaRepositoryPort(mock_repository)
 
        #Definindo o comportamento esperado do mock
        mock_repository.listar.return_value = [self.pessoa_aline, self.pessoa_joao]
       
        pessoas = pessoa_repository_port.listar()
 
        mock_repository.listar.assert_called_once()
       
        assert len(pessoas) == 2   

    def test_deve_retornar_sucesso_quando_excluir_pessoa_cadastrada(self):
        mock_repository = Mock(spec = InMemoryPessoaRepository)
        pessoa_repository_port = PessoaRepositoryPort(mock_repository)

        pessoa_aline = Pessoa(self.aline_nome, self.aline_cpf)

        #Definindo o comportamento esperado do mock   
        mock_repository.excluir.return_value = None
        pessoa_repository_port.excluir(pessoa_aline)
        mock_repository.excluir.asset_called_once_with(pessoa_aline)


    def test_deve_retornar_sucesso_quando_obter_pessoa_por_cpf(self):
        mock_repository = Mock(spec = InMemoryPessoaRepository)
        pessoa_repository_port = PessoaRepositoryPort(mock_repository)

        #Definindo o comportamento esperado do mock
        mock_repository.buscar_por_cpf.return_value =  self.pessoa_aline

        pessoa_cadastrada = pessoa_repository_port.buscar_por_cpf(self.aline_cpf)
        
        assert pessoa_cadastrada is not None
        assert pessoa_cadastrada.cpf == self.aline_cpf
        assert pessoa_cadastrada.nome == self.aline_nome