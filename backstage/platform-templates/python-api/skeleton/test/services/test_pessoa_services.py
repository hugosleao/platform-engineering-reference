import pytest
from unittest.mock import Mock
from src.domain.models.pessoa import Pessoa
from src.domain.ports.pessoa_repository_port import PessoaRepositoryPort
from src.adapters.repositories import InMemoryPessoaRepository
from src.domain.services.pessoa_services import PessoaService

class TestPessoaService():
    @classmethod
    def setup_class(cls):
        cls.aline_nome = 'Aline da Silva'
        cls.aline_cpf = '139.649.293-36'
        cls.pessoa_aline = Pessoa(cls.aline_nome, cls.aline_cpf)
        cls.pessoa_joao = Pessoa("Joao", "762.263.731-99")

    def test_deve_retornar_sucesso_ao_salvar_pessoa(self):
             
        mock_pessoa_repository_port = Mock(spec = PessoaRepositoryPort)
        mock_pessoa_repository_port.buscar_por_cpf.return_value = None
        mock_pessoa_repository_port.salvar.return_value  =  self.pessoa_aline
        mock_pessoa_service = PessoaService(mock_pessoa_repository_port)
      
        pessoa_cadastrada = mock_pessoa_service.salvar(self.aline_nome, self.aline_cpf)

        assert pessoa_cadastrada is not None
        assert pessoa_cadastrada.cpf == self.aline_cpf
        assert pessoa_cadastrada.nome == self.aline_nome


    def test_deve_retornar_sucesso_quando_obter_lista_pessoas_cadastradas(self):
        mock_pessoa_repository_port = Mock(spec = PessoaRepositoryPort)

        #Definindo o comportamento esperado do mock
        mock_pessoa_repository_port.listar.return_value =  [self.pessoa_aline, self.pessoa_joao]

        mock_pessoa_service = PessoaService(mock_pessoa_repository_port)
        pessoas = mock_pessoa_service.listar()

        mock_pessoa_repository_port.listar.asset_called_once()
        
        assert len(pessoas) == 2   

    def test_deve_retornar_sucesso_quando_excluir_pessoa_cadastrada(self):
        mock_pessoa_repository_port = Mock(spec = PessoaRepositoryPort)
        mock_pessoa_service = PessoaService(mock_pessoa_repository_port)
        mock_pessoa_service.excluir(self.aline_cpf)
        mock_pessoa_repository_port.excluir.asset_called_once(self.pessoa_aline)

        
    def test_deve_retornar_erro_quando_executar_excluir_com_cpf_nao_pessoa_cadastrada(self):
        mock_pessoa_repository_port = Mock(spec = PessoaRepositoryPort)
        mock_pessoa_repository_port.excluir.return_value = None
        mock_pessoa_repository_port.buscar_por_cpf.return_value = None

        mock_pessoa_service = PessoaService(mock_pessoa_repository_port)
        with pytest.raises(Exception) as context:
                mock_pessoa_service.excluir(self.aline_cpf)
        
        assert str(context.value) == 'Pessoa não cadastrada !'